import DeviceActivity
import FamilyControls
import Foundation

struct DailyMonitorInspection: Sendable {
    let activityNames: [String]
    let eventCount: Int
    let configurationMatches: Bool
}

/// Screen Time IPC can take time. Keep registration and its minute-by-minute
/// health checks off the main actor so the interface remains responsive.
actor DailyMonitorService {
    private let center = DeviceActivityCenter()

    func inspect(activityName: String, selectionData: Data?) throws -> DailyMonitorInspection {
        let selection = try decodeSelection(selectionData)
        let activity = DeviceActivityName(activityName)
        let names = center.activities.map(\.rawValue)
        guard names.contains(activityName), let schedule = center.schedule(for: activity) else {
            return DailyMonitorInspection(activityNames: names, eventCount: 0, configurationMatches: false)
        }
        let events = center.events(for: activity)
        let expectedNames = Set(GateState.usageCheckpoints.map { "gate.usage.\($0)" })
        let matchesEvents = Set(events.keys.map(\.rawValue)) == expectedNames && events.allSatisfy { name, event in
            guard let minute = Int(name.rawValue.dropFirst("gate.usage.".count)) else { return false }
            let seconds = (event.threshold.day ?? 0) * 86400 + (event.threshold.hour ?? 0) * 3600
                + (event.threshold.minute ?? 0) * 60 + (event.threshold.second ?? 0)
            return seconds == minute * 60 && event.includesPastActivity
                && event.applications == selection.applicationTokens
                && event.webDomains == selection.webDomainTokens && event.categories.isEmpty
        }
        let matchesSchedule = schedule.repeats
            && schedule.intervalStart.hour == 0 && schedule.intervalStart.minute == 0
            && (schedule.intervalStart.second ?? 0) == 0
            && schedule.intervalEnd.hour == 23 && schedule.intervalEnd.minute == 59 && schedule.intervalEnd.second == 59
        return DailyMonitorInspection(activityNames: names, eventCount: events.count,
                                      configurationMatches: matchesEvents && matchesSchedule)
    }

    func install(activityName: String, selectionData: Data?) throws -> DailyMonitorInspection {
        let selection = try decodeSelection(selectionData)
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59), repeats: true)
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for minute in GateState.usageCheckpoints.sorted() {
            events[DeviceActivityEvent.Name("gate.usage.\(minute)")] = DeviceActivityEvent(
                applications: selection.applicationTokens, webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: minute), includesPastActivity: true)
        }
        // Updating the same activity replaces its schedule/events. Do not stop it
        // first, and do not zero the persisted daily total on reconnection.
        try center.startMonitoring(DeviceActivityName(activityName), during: schedule, events: events)
        return try inspect(activityName: activityName, selectionData: selectionData)
    }

    func retireOtherDailyMonitors(keeping name: String) {
        let old = center.activities.filter {
            ($0.rawValue == "gate.daily" || $0.rawValue.hasPrefix("gate.daily.")) && $0.rawValue != name
        }
        if !old.isEmpty { center.stopMonitoring(old) }
        center.stopMonitoring([DeviceActivityName("gate.grant")]) // Pre-0.2 single-grant migration only.
    }

    private func decodeSelection(_ data: Data?) throws -> FamilyActivitySelection {
        guard let data,
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data),
              selection.categoryTokens.isEmpty,
              !selection.applicationTokens.isEmpty || !selection.webDomainTokens.isEmpty else {
            // Empty DeviceActivityEvent selections mean ALL activity. Never use
            // that fallback: Phone and WhatsApp must stay outside the saved pool.
            throw MonitorError.missingSelection
        }
        return selection
    }

    enum MonitorError: LocalizedError {
        case missingSelection, registrationIncomplete
        var errorDescription: String? {
            switch self {
            case .missingSelection: return "Keine gültige gespeicherte App-Auswahl. Prüfe deine Ablenkungen unter Mehr."
            case .registrationIncomplete: return "iOS hat die Nutzungsmessung noch nicht vollständig registriert. Gate versucht es erneut."
            }
        }
    }
}

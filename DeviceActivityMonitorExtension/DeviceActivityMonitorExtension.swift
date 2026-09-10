import DeviceActivity
import Foundation
import WidgetKit
import OSLog

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "ch.mauruspichler.gate", category: "Monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        update { state in
            guard state.monitoringEnabled,
                  activity.rawValue == state.dailyActivityName || activity.rawValue == state.previousDailyActivityName else { return }
            state.rollDay(at: Date())
            state.lastDailyMonitorCallbackAt = Date()
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        update { state in
            guard state.monitoringEnabled else { return }
            state.rollDay(at: Date())
            if activity.rawValue == state.dailyActivityName || activity.rawValue == state.previousDailyActivityName {
                state.recordDailyUsageEvent(event.rawValue, activity: activity.rawValue, at: Date())
            } else if let index = state.grants.firstIndex(where: { $0.activityName == activity.rawValue }),
                      event.rawValue.hasPrefix("gate.used."),
                      let minutes = Int(event.rawValue.dropFirst("gate.used.".count)),
                      (1...state.grants[index].minutes).contains(minutes) {
                state.grants[index].usedMinutes = max(state.grants[index].usedMinutes, minutes)
            }
            state.expireGrants(at: Date())
        }
        if activity.rawValue.hasPrefix("gate.grant."),
           let state = try? GateSharedStore.read(),
           !state.grants.contains(where: { $0.activityName == activity.rawValue }) {
            DeviceActivityCenter().stopMonitoring([activity])
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue.hasPrefix("gate.grant.") else { return }
        update { state in state.grants.removeAll { $0.activityName == activity.rawValue } }
        DeviceActivityCenter().stopMonitoring([activity])
    }

    private func update(_ body: (inout GateState) -> Void) {
        do {
            var refreshWidget = false
            try GateSharedStore.transaction(afterCommit: { GateShieldPolicy.apply($0) }, onlyWhenProtectionChanges: true) { state in
                let previousProtection = state.protectionInputs
                let previousDay = state.day
                state.rollDay(at: Date())
                state.reconcileAllowance(at: Date())
                body(&state)
                refreshWidget = previousDay != state.day || previousProtection != state.protectionInputs
            }
            // The widget displays protection/grant status, not a live counter.
            // Backfilled minute events should not exhaust its refresh budget.
            if refreshWidget { WidgetCenter.shared.reloadTimelines(ofKind: "GateLauncher") }
        } catch {
            // Do not clear an existing shield if persistence is unavailable.
            logger.error("Monitor state update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

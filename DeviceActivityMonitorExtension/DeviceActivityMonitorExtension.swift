import DeviceActivity
import Foundation
import WidgetKit
import OSLog

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "ch.mauruspichler.gate", category: "Monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        update { state in
            guard activity.rawValue == state.dailyActivityName else { return }
            state.rollDay(at: Date())
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        update { state in
            guard state.monitoringEnabled else { return }
            state.rollDay(at: Date())
            if activity.rawValue == state.dailyActivityName,
               let minutes = Int(event.rawValue.replacingOccurrences(of: "gate.usage.", with: "")) {
                state.recordUsage(minutes, at: Date())
            } else if let index = state.grants.firstIndex(where: { $0.activityName == activity.rawValue }),
                      let minutes = Int(event.rawValue.replacingOccurrences(of: "gate.used.", with: "")) {
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
            try GateSharedStore.transaction(afterCommit: { GateShieldPolicy.apply($0) }) { state in
                body(&state)
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "GateLauncher")
        } catch {
            // Do not clear an existing shield if persistence is unavailable.
            logger.error("Monitor state update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

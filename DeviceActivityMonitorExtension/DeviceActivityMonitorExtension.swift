import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private enum Shared {
        static let appGroup = "group.ch.mauruspichler.gate"
        static let selectionKey = "gate.selection"
        static let limitReachedKey = "gate.limitReached"
        static let pendingTargetKey = "gate.pendingTarget"
        static let activeGrantKey = "gate.activeGrant"
        static let failuresKey = "gate.consecutiveFailures"
        static let cooldownKey = "gate.cooldownUntil"

        static let dailyActivity = DeviceActivityName("gate.daily")
        static let dailyLimitEvent = DeviceActivityEvent.Name("gate.daily.free-limit")
        static let grantActivity = DeviceActivityName("gate.grant")
        static let grantLimitEvent = DeviceActivityEvent.Name("gate.grant.limit")
    }

    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard activity == Shared.dailyActivity else { return }
        let defaults = sharedDefaults
        defaults.set(false, forKey: Shared.limitReachedKey)
        defaults.removeObject(forKey: Shared.pendingTargetKey)
        defaults.removeObject(forKey: Shared.activeGrantKey)
        defaults.set(0, forKey: Shared.failuresKey)
        defaults.removeObject(forKey: Shared.cooldownKey)
        clearUsageShields()
        applyAlwaysOnProtections()
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        if activity == Shared.dailyActivity, event == Shared.dailyLimitEvent {
            sharedDefaults.set(true, forKey: Shared.limitReachedKey)
            applyFullUsageShield()
            return
        }

        if activity == Shared.grantActivity, event == Shared.grantLimitEvent {
            sharedDefaults.removeObject(forKey: Shared.activeGrantKey)
            applyFullUsageShield()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard activity == Shared.grantActivity else { return }
        sharedDefaults.removeObject(forKey: Shared.activeGrantKey)
        applyFullUsageShield()
    }

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: Shared.appGroup) ?? .standard
    }

    private func loadSelection() -> FamilyActivitySelection {
        guard
            let data = sharedDefaults.data(forKey: Shared.selectionKey),
            let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    private func applyFullUsageShield() {
        let selection = loadSelection()
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
            store.shield.webDomainCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens, except: Set())
            store.shield.webDomainCategories = .specific(selection.categoryTokens, except: Set())
        }
        applyAlwaysOnProtections()
    }

    private func clearUsageShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }

    private func applyAlwaysOnProtections() {
        store.webContent.blockedByFilter = .auto()
        store.media.denyExplicitContent = true
        store.media.denyBookstoreErotica = true
    }
}

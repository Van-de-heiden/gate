import FamilyControls
import Foundation

enum GateStorage {
    private enum Key {
        static let selection = "gate.selection"
        static let monitoringEnabled = "gate.monitoringEnabled"
        static let limitReached = "gate.limitReached"
        static let pendingTarget = "gate.pendingTarget"
        static let activeGrant = "gate.activeGrant"
        static let consecutiveFailures = "gate.consecutiveFailures"
        static let cooldownUntil = "gate.cooldownUntil"
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: GateConstants.appGroupIdentifier) ?? .standard
    }

    private static let encoder = PropertyListEncoder()
    private static let decoder = PropertyListDecoder()

    static func saveSelection(_ selection: FamilyActivitySelection) throws {
        defaults.set(try encoder.encode(selection), forKey: Key.selection)
    }

    static func loadSelection() -> FamilyActivitySelection {
        guard
            let data = defaults.data(forKey: Key.selection),
            let selection = try? decoder.decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static var monitoringEnabled: Bool {
        get { defaults.bool(forKey: Key.monitoringEnabled) }
        set { defaults.set(newValue, forKey: Key.monitoringEnabled) }
    }

    static var limitReached: Bool {
        get { defaults.bool(forKey: Key.limitReached) }
        set { defaults.set(newValue, forKey: Key.limitReached) }
    }

    static var pendingTarget: GateTarget? {
        get { decode(GateTarget.self, key: Key.pendingTarget) }
        set { encode(newValue, key: Key.pendingTarget) }
    }

    static var activeGrant: GateGrant? {
        get { decode(GateGrant.self, key: Key.activeGrant) }
        set { encode(newValue, key: Key.activeGrant) }
    }

    static var consecutiveFailures: Int {
        get { defaults.integer(forKey: Key.consecutiveFailures) }
        set { defaults.set(newValue, forKey: Key.consecutiveFailures) }
    }

    static var cooldownUntil: Date? {
        get { defaults.object(forKey: Key.cooldownUntil) as? Date }
        set { defaults.set(newValue, forKey: Key.cooldownUntil) }
    }

    static func resetSessionState() {
        limitReached = false
        pendingTarget = nil
        activeGrant = nil
        consecutiveFailures = 0
        cooldownUntil = nil
    }

    private static func encode<T: Encodable>(_ value: T?, key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(try? encoder.encode(value), forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}


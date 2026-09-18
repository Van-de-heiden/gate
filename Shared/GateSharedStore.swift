import Foundation
import Darwin

enum GateSharedStore {
    static let appGroup = "group.ch.mauruspichler.gate"
    private static let localLock = NSLock()

    enum StorageError: LocalizedError {
        case appGroupMissing, lockUnavailable, unsupportedVersion
        var errorDescription: String? {
            switch self {
            case .appGroupMissing: return "Die App Group ist nicht verfügbar. Prüfe Signing & Capabilities für alle Gate-Targets."
            case .lockUnavailable: return "Der gemeinsame Gate-Speicher ist gerade nicht verfügbar."
            case .unsupportedVersion: return "Diese Gate-Daten stammen aus einer neueren Version. Bitte Gate aktualisieren."
            }
        }
    }

    static func read() throws -> GateState { try transaction { $0 } }

    /// Coordinates app, monitor and shield processes. Never fall back to an unrelated defaults suite.
    @discardableResult
    static func transaction<T>(afterCommit: ((GateState) -> Void)? = nil,
                               onlyWhenProtectionChanges: Bool = false,
                               _ update: (inout GateState) throws -> T) throws -> T {
        localLock.lock()
        defer { localLock.unlock() }
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        else { throw StorageError.appGroupMissing }
        let descriptor = open(folder.appendingPathComponent("gate-state.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw StorageError.lockUnavailable }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw StorageError.lockUnavailable }
        defer { flock(descriptor, LOCK_UN) }
        let file = folder.appendingPathComponent("gate-state-v2.json")
        var state: GateState
        if FileManager.default.fileExists(atPath: file.path) {
            state = try JSONDecoder().decode(GateState.self, from: Data(contentsOf: file))
            guard state.version == 2 else { throw StorageError.unsupportedVersion }
        } else {
            state = GateState()
            state.selectionData = UserDefaults(suiteName: appGroup)?.data(forKey: "gate.selection")
            // The old single-grant monitor cannot be safely imported. Re-arm explicitly in the app.
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(state)
        let previousProtection = state.protectionInputs
        let result = try update(&state)
        let after = try encoder.encode(state)
        if before != after || !FileManager.default.fileExists(atPath: file.path) {
            try after.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        if !onlyWhenProtectionChanges || previousProtection != state.protectionInputs {
            afterCommit?(state)
        }
        return result
    }
}

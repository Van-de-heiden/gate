import Foundation

enum GateTargetKind: String, Codable {
    case application, webDomain, category
    var displayName: String { self == .application ? "App" : self == .webDomain ? "Website" : "Kategorie" }
}

struct GateTarget: Codable, Equatable, Identifiable {
    let kind: GateTargetKind
    let tokenData: Data
    // Request time deliberately does not participate in target identity.
    var id: String { kind.rawValue + ":" + tokenData.base64EncodedString() }
}

struct GateRequest: Codable, Equatable, Identifiable {
    var id = UUID()
    let target: GateTarget
    var requestedAt = Date()
}

struct GateGrant: Codable, Equatable, Identifiable {
    var id = UUID()
    let target: GateTarget
    let minutes: Int
    let grantedAt: Date
    let expiresAt: Date
    var usedMinutes = 0
    var armed = false
    var activityName: String { "gate.grant." + id.uuidString }
    func isActive(at date: Date) -> Bool { armed && expiresAt > date && usedMinutes < minutes }
}

struct GateAttempt: Codable, Equatable {
    var failures = 0
    var cooldownUntil: Date?
    mutating func fail(at now: Date) {
        failures += 1
        if failures.isMultiple(of: 3) { cooldownUntil = now.addingTimeInterval(15 * 60) }
    }
}

struct GateUsageDay: Codable, Identifiable {
    var id: Date
    var confirmedMinutes = 0
    var earnedMinutes = 0
    var grants = 0
}

struct LauncherItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var url: String
    var enabled = true
    // Launcher links never grant Screen Time exceptions.
    static let defaults: [LauncherItem] = [
        .init(title: "WhatsApp", url: "whatsapp://"),
        .init(title: "Lesen", url: "ibooks://"),
        .init(title: "Kalender", url: "calshow://"),
        .init(title: "Karten", url: "https://maps.apple.com"),
        .init(title: "YouTube", url: "https://www.youtube.com"),
        .init(title: "Snapchat", url: "snapchat://")
    ]
    var validatedURL: URL? {
        guard let parsed = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parsed.scheme?.lowercased(),
              !["file", "javascript", "data", "gate", "prefs", "app-prefs"].contains(scheme)
        else { return nil }
        if ["http", "https"].contains(scheme), parsed.host?.isEmpty != false { return nil }
        return parsed
    }
}

struct GateState: Codable {
    static let everydayFreeMinutes = 30
    var version = 2
    var day = Calendar.current.startOfDay(for: Date())
    var selectionData: Data?
    var selectionLocked: Bool?
    var protectedSelectionData: Data?
    var pauseRequestedAt: Date?
    var isSelectionLocked: Bool { selectionLocked ?? (selectionData != nil) }
    var monitoringEnabled = false
    var dailyActivityName = "gate.daily.\(UUID().uuidString)"
    var previousDailyActivityName: String?
    var lastDailyMonitorInstallAt: Date?
    var lastDailyMonitorCallbackAt: Date?
    var freeMinutes = GateState.everydayFreeMinutes
    var testModeStartedAt: Date?
    var confirmedMinutes = 0
    var lastUsageUpdate: Date?
    var limitReached = false
    var grants: [GateGrant] = []
    var requests: [GateRequest] = []
    var attempts: [String: GateAttempt] = [:]
    var aliases: [String: String] = [:]
    var history: [GateUsageDay] = []
    var onboardingComplete = false
    var launcher = LauncherItem.defaults

    static let usageCheckpoints = Set(1...(24 * 60))
    var isTestMode: Bool { freeMinutes == 2 }
    var remainingFreeMinutes: Int { max(0, freeMinutes - confirmedMinutes) }

    var protectionInputs: GateProtectionInputs {
        GateProtectionInputs(selection: selectionData, permanentSelection: protectedSelectionData,
            monitoringEnabled: monitoringEnabled, limitReached: limitReached,
            // Deliberately use persisted grants here. An expired grant is removed by
            // expireGrants, which must count as a policy change even after its deadline.
            exemptTargetIDs: Set(grants.filter { $0.armed && $0.usedMinutes < $0.minutes }.map(\.target.id)))
    }

    mutating func useEverydayMode() {
        freeMinutes = Self.everydayFreeMinutes
        testModeStartedAt = nil
        reconcileAllowance(at: Date())
    }

    mutating func beginTestMode(at now: Date) {
        freeMinutes = 2
        testModeStartedAt = now
        reconcileAllowance(at: now)
    }

    mutating func reconcileAllowance(at now: Date, calendar: Calendar = .current) {
        // Migrate persisted everyday budgets (including the former 60 minutes)
        // without resetting usage, history, selection or existing grants.
        // Only an explicitly started same-day test retains its two-minute limit.
        let currentTest = isTestMode && testModeStartedAt.map { calendar.isDate($0, inSameDayAs: now) } == true
        if !currentTest {
            freeMinutes = Self.everydayFreeMinutes
            testModeStartedAt = nil
        }
        limitReached = confirmedMinutes >= freeMinutes
        if !limitReached { requests.removeAll() }
    }

    mutating func rollDay(at now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        guard today > day else { return }
        day = today
        confirmedMinutes = 0
        lastUsageUpdate = nil
        lastDailyMonitorCallbackAt = nil
        limitReached = false
        grants = []
        requests = []
        attempts = [:]
        freeMinutes = Self.everydayFreeMinutes
        testModeStartedAt = nil
        history = Array(history.suffix(90))
    }

    mutating func expireGrants(at now: Date) {
        grants.removeAll { $0.expiresAt <= now || $0.usedMinutes >= $0.minutes }
        requests.removeAll { now.timeIntervalSince($0.requestedAt) > 60 * 60 }
    }

    func activeGrants(at now: Date) -> [GateGrant] { grants.filter { $0.isActive(at: now) } }
    func grant(for target: GateTarget, at now: Date) -> GateGrant? {
        activeGrants(at: now).first { $0.target.id == target.id }
    }

    mutating func enqueue(_ target: GateTarget, at now: Date = Date()) -> GateRequest? {
        guard monitoringEnabled, limitReached, grant(for: target, at: now) == nil else { return nil }
        if let index = requests.firstIndex(where: { $0.target.id == target.id }) {
            requests[index].requestedAt = now
            return requests[index]
        }
        let request = GateRequest(target: target, requestedAt: now)
        requests.append(request)
        requests = Array(requests.suffix(20))
        return request
    }

    mutating func recordUsage(_ minutes: Int, at now: Date) {
        guard minutes > confirmedMinutes else { return }
        confirmedMinutes = minutes
        lastUsageUpdate = now
        limitReached = confirmedMinutes >= freeMinutes
        let index = usageIndex()
        history[index].confirmedMinutes = confirmedMinutes
    }

    /// The callback has no measured duration payload: only registered threshold names
    /// are evidence. Never count a timer tick, registration check or stale grant event.
    mutating func recordDailyUsageEvent(_ event: String, activity: String, at now: Date) {
        guard monitoringEnabled,
              activity == dailyActivityName || activity == previousDailyActivityName,
              event.hasPrefix("gate.usage."),
              let minutes = Int(event.dropFirst("gate.usage.".count)),
              event == "gate.usage.\(minutes)",
              Self.usageCheckpoints.contains(minutes) else { return }
        lastDailyMonitorCallbackAt = now
        recordUsage(minutes, at: now)
    }

    mutating func recordGrant(_ minutes: Int) {
        let index = usageIndex()
        history[index].earnedMinutes += minutes
        history[index].grants += 1
    }

    private mutating func usageIndex() -> Int {
        if let index = history.firstIndex(where: { $0.id == day }) { return index }
        history.append(GateUsageDay(id: day))
        return history.count - 1
    }
}

struct GateProtectionInputs: Equatable {
    let selection: Data?
    let permanentSelection: Data?
    let monitoringEnabled: Bool
    let limitReached: Bool
    let exemptTargetIDs: Set<String>
}

enum GateMonitorCadence {
    static func shouldCheck(at now: Date, lastAttempt: Date?, enabled: Bool,
                            authorized: Bool, checking: Bool, force: Bool = false) -> Bool {
        guard enabled, authorized, !checking else { return false }
        guard !force, let lastAttempt else { return true }
        // A clock correction must not postpone checks indefinitely.
        let elapsed = now.timeIntervalSince(lastAttempt)
        return elapsed >= 60 || elapsed < 0
    }
}

enum AdditiveSelection {
    static func retaining<T: Hashable>(_ saved: Set<T>, adding proposed: Set<T>) -> Set<T> {
        saved.union(proposed)
    }
    static func launcher(_ saved: [LauncherItem], adding proposed: [LauncherItem]) -> [LauncherItem] {
        // Reordering is permitted; old destinations and enabled state cannot be changed to evade the lock.
        let old = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
        var seen = Set<UUID>()
        var result = proposed.filter { seen.insert($0.id).inserted }.map { old[$0.id] ?? $0 }
        result.append(contentsOf: saved.filter { seen.insert($0.id).inserted })
        return result.map { var item = $0; item.enabled = true; return item }
    }
}

enum LessonLoad {
    static let allowedMinutes = [5, 10, 15, 20, 30]
    static func questionCount(minutes: Int, consumedMinutes: Int, failures: Int) -> Int {
        let base = minutes <= 5 ? 3 : minutes <= 10 ? 5 : minutes <= 15 ? 7 : minutes <= 20 ? 9 : 12
        let usage = min(3, max(0, (consumedMinutes - GateState.everydayFreeMinutes) / 30))
        return min(20, base + usage + min(4, max(0, failures)))
    }
    static func passes(correct: Int, total: Int) -> Bool {
        total > 0 && correct * 5 >= total * 4
    }
}

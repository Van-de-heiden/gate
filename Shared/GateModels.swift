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
    var version = 2
    var day = Calendar.current.startOfDay(for: Date())
    var selectionData: Data?
    var monitoringEnabled = false
    var dailyActivityName = "gate.daily.\(UUID().uuidString)"
    var freeMinutes = 60
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

    mutating func rollDay(at now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        guard today > day else { return }
        day = today
        confirmedMinutes = 0
        lastUsageUpdate = nil
        limitReached = false
        grants = []
        requests = []
        attempts = [:]
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
        confirmedMinutes = max(confirmedMinutes, minutes)
        lastUsageUpdate = now
        if confirmedMinutes >= freeMinutes { limitReached = true }
        let index = usageIndex()
        history[index].confirmedMinutes = confirmedMinutes
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

enum LessonLoad {
    static let allowedMinutes = [5, 10, 15]
    static func questionCount(minutes: Int, consumedMinutes: Int, failures: Int) -> Int {
        let base = minutes <= 5 ? 3 : minutes <= 10 ? 5 : 7
        let usage = min(3, max(0, (consumedMinutes - 60) / 30))
        return min(14, base + usage + min(4, max(0, failures)))
    }
    static func passes(correct: Int, total: Int) -> Bool {
        total > 0 && correct * 5 >= total * 4
    }
}

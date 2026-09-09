import DeviceActivity
import Foundation

enum GateConstants {
    static let appGroupIdentifier = "group.ch.pichler.gate"

    static let dailyActivity = DeviceActivityName("gate.daily")
    static let dailyLimitEvent = DeviceActivityEvent.Name("gate.daily.free-limit")
    static let grantActivity = DeviceActivityName("gate.grant")
    static let grantLimitEvent = DeviceActivityEvent.Name("gate.grant.limit")

    #if DEBUG
    static let dailyFreeMinutes = 2
    static let isDebugAllowance = true
    #else
    static let dailyFreeMinutes = 60
    static let isDebugAllowance = false
    #endif

    static let prototypeGrantMinutes = 5
    static let grantExpiryMinutes = 30
    static let cooldownMinutes = 15
}

enum GateTargetKind: String, Codable {
    case application
    case webDomain
    case category

    var displayName: String {
        switch self {
        case .application: "App"
        case .webDomain: "Website"
        case .category: "Kategorie"
        }
    }
}

struct GateTarget: Codable, Equatable {
    let kind: GateTargetKind
    let tokenData: Data
    let requestedAt: Date
}

struct GateGrant: Codable, Equatable {
    let target: GateTarget
    let minutes: Int
    let grantedAt: Date
    let expiresAt: Date
}


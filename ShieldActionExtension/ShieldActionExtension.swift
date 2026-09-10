import Foundation
import ManagedSettings
import UserNotifications
import OSLog

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, token: application, kind: .application, completion: completionHandler)
    }
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, token: webDomain, kind: .webDomain, completion: completionHandler)
    }
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Never grant a complete category.
        completionHandler(.close)
    }

    private func handle<T: Encodable>(_ action: ShieldAction, token: T, kind: GateTargetKind, completion: @escaping (ShieldActionResponse) -> Void) {
        guard action == .primaryButtonPressed else { completion(.close); return }
        do {
            let target = GateTarget(kind: kind, tokenData: try PropertyListEncoder().encode(token))
            let protected = try GateSharedStore.transaction { state -> Bool in
                guard GateShieldPolicy.isProtected(target, in: state) else { return false }
                state.pauseRequestedAt = Date()
                return true
            }
            if protected {
                let content = UNMutableNotificationContent()
                content.title = "Gate · Ein Impuls ist kein Auftrag."
                content.body = "Tippe hier für eine ruhige Minute und deinen nächsten Schritt. Die Website bleibt geschützt."
                content.userInfo = ["gatePause": true]
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "gate.pause", content: content, trigger: nil))
                completion(.close)
                return
            }
            let request = try GateSharedStore.transaction { state -> GateRequest? in
                state.rollDay(at: Date())
                state.expireGrants(at: Date())
                return state.enqueue(target)
            }
            guard let request else { completion(.close); return }
            // The notification path works without a beta SDK or private URL-opening API.
                let content = UNMutableNotificationContent()
                content.title = "Ein Moment für dein Wissen."
                content.body = "Gate öffnen und diese \(kind.displayName) freigeben. Andere Freigaben bleiben bestehen."
                content.userInfo = ["gateRequestID": request.id.uuidString]
                UNUserNotificationCenter.current().add(UNNotificationRequest(
                    identifier: "gate.request.\(request.id.uuidString)", content: content, trigger: nil
                ))
                completion(.close)
        } catch {
            Logger(subsystem: "ch.mauruspichler.gate", category: "Shield").error("Request failed: \(error.localizedDescription, privacy: .public)")
            completion(.close)
        }
    }
}

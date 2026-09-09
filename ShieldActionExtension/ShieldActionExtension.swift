import Foundation
import ManagedSettings
import UserNotifications

final class ShieldActionExtension: ShieldActionDelegate {
    private enum TargetKind: String, Codable {
        case application
        case webDomain
        case category
    }

    private struct PendingTarget: Codable {
        let kind: TargetKind
        let tokenData: Data
        let requestedAt: Date
    }

    private let appGroup = "group.ch.pichler.gate"
    private let pendingTargetKey = "gate.pendingTarget"

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, token: application, kind: .application, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, token: webDomain, kind: .webDomain, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handle(action: action, token: category, kind: .category, completionHandler: completionHandler)
    }

    private func handle<Token: Encodable>(
        action: ShieldAction,
        token: Token,
        kind: TargetKind,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        guard action == .primaryButtonPressed else {
            completionHandler(.close)
            return
        }

        do {
            let tokenData = try PropertyListEncoder().encode(token)
            let pending = PendingTarget(kind: kind, tokenData: tokenData, requestedAt: Date())
            let data = try PropertyListEncoder().encode(pending)
            let defaults = UserDefaults(suiteName: appGroup) ?? .standard
            defaults.set(data, forKey: pendingTargetKey)

            if #available(iOS 27.0, *) {
                completionHandler(.openParentalControlsApp)
            } else {
                scheduleOpenGateNotification()
                completionHandler(.close)
            }
        } catch {
            completionHandler(.close)
        }
    }

    private func scheduleOpenGateNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Gate"
        content.body = "Tippe hier, absolviere die Lektion und verdiene fünf Minuten Zugang."

        let request = UNNotificationRequest(
            identifier: "gate.open.lesson",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

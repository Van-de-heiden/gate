import SwiftUI
import UIKit
import UserNotifications

extension Notification.Name {
    static let gateRequestOpened = Notification.Name("gate.request.opened")
    static let gatePauseOpened = Notification.Name("gate.pause.opened")
}

final class GateAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.userInfo["gatePause"] as? Bool == true {
            DispatchQueue.main.async { NotificationCenter.default.post(name: .gatePauseOpened, object: nil) }
        }
        if let string = response.notification.request.content.userInfo["gateRequestID"] as? String,
           let id = UUID(uuidString: string) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .gateRequestOpened, object: nil, userInfo: ["id": id])
            }
        }
        completionHandler()
    }
}

@main
struct GateApp: App {
    @UIApplicationDelegateAdaptor(GateAppDelegate.self) private var delegate
    @StateObject private var controller = ScreenTimeController()
    var body: some Scene { WindowGroup { ContentView(controller: controller) } }
}

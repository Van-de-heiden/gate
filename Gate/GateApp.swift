import SwiftUI

@main
struct GateApp: App {
    @StateObject private var controller = ScreenTimeController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(controller: controller)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        controller.refreshSharedState()
                    }
                }
        }
    }
}


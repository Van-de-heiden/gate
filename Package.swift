// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GateCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "GateCore", targets: ["GateCore"])],
    targets: [
        .target(name: "GateCore", path: ".",
            exclude: ["Gate.xcodeproj", "GateWidgetExtension", "DeviceActivityMonitorExtension",
                "ShieldActionExtension", "ShieldConfigurationExtension", "ScreenTimeShared",
                "Tests", "scripts", "docs", "README.md", "LICENSE", "Shared/GateSharedStore.swift",
                "Gate/Assets.xcassets", "Gate/ContentView.swift", "Gate/DesignSystem.swift", "Gate/AllowanceGauge.swift",
                "Gate/Gate.entitlements", "Gate/GateApp.swift", "Gate/Info.plist",
                "Gate/GateSettingsView.swift", "Gate/GateStatisticsView.swift", "Gate/LearningLibraryView.swift", "Gate/MonitoringStatusView.swift",
                "Gate/LearningStore.swift", "Gate/LessonView.swift", "Gate/ScreenTimeController.swift", "Gate/DailyMonitorService.swift",
                "Gate/QuestionView.swift", "Gate/KeyboardSupport.swift", "Gate/LessonArtwork.swift", "Gate/IntentionalPauseView.swift"],
            sources: ["Shared/GateModels.swift", "LearningCore/LearningModels.swift"],
            resources: [.copy("Gate/curriculum.json")]),
        .testTarget(name: "GateCoreTests", dependencies: ["GateCore"], path: "Tests/GateCoreTests")
    ]
)

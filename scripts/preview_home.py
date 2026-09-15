"""Render the real shared SwiftUI home components in an isolated simulator app.

No Screen Time permission, app-group access, installed Gate state or production
launch arguments are used. Screenshots check layout, not blocking behaviour.
"""
import json
from pathlib import Path
import platform
import plistlib
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "home-previews"
OUTPUT.mkdir(exist_ok=True)


def run(*args):
    return subprocess.check_output(args, text=True).strip()


with tempfile.TemporaryDirectory(prefix="gate-home-preview-") as temporary:
    folder = Path(temporary)
    app = folder / "GateHomePreview.app"
    app.mkdir()
    sources = []
    for relative in ["Shared/GateModels.swift", "Gate/DesignSystem.swift",
                     "Gate/GateAtmosphere.swift", "Gate/AllowanceGauge.swift", "Gate/HomeScene.swift"]:
        source = (ROOT / relative).read_text()
        # SwiftUI's #Preview macro is Xcode-only; the same view runs below as a tiny app.
        source = source.split("#Preview(")[0]
        if relative == "Gate/HomeScene.swift":
            source += "\n#endif\n"
        target = folder / Path(relative).name
        target.write_text(source)
        sources.append(str(target))
    main = folder / "PreviewApp.swift"
    main.write_text('''import SwiftUI
@main struct PreviewApp: App {
    private let args = ProcessInfo.processInfo.arguments
    var body: some Scene {
        let rawPhase = args.first { $0.hasPrefix("--phase=") }?.replacingOccurrences(of: "--phase=", with: "") ?? "day"
        let phase = GateDayPhase(rawValue: rawPhase) ?? .day
        WindowGroup {
            GateHomeScenePreview(phase: phase, remaining: args.contains("--empty") ? 0 : 21)
                .dynamicTypeSize(args.contains("--large") ? .accessibility3 : .large)
        }
    }
}
''')
    sdk = run("xcrun", "--sdk", "iphonesimulator", "--show-sdk-path")
    subprocess.run(["xcrun", "swiftc", "-DDEBUG", "-parse-as-library",
                    "-target", f"{platform.machine()}-apple-ios17.4-simulator", "-sdk", sdk,
                    *sources, str(main), "-o", str(app / "GateHomePreview")], check=True)
    identifier = "ch.mauruspichler.gate.homepreview"
    with (app / "Info.plist").open("wb") as stream:
        plistlib.dump({"CFBundleIdentifier": identifier, "CFBundleExecutable": "GateHomePreview",
                      "CFBundleName": "Gate Preview", "CFBundlePackageType": "APPL",
                      "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0",
                      "MinimumOSVersion": "17.4", "UILaunchScreen": {},
                      "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False},
                      "UIDeviceFamily": [1],
                      "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"]}, stream)
    subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
    runtimes = json.loads(run("xcrun", "simctl", "list", "runtimes", "available", "--json"))["runtimes"]
    runtime = next(r["identifier"] for r in reversed(runtimes) if "iOS" in r["identifier"])
    device = run("xcrun", "simctl", "create", "Gate Home Preview",
                 "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Plus", runtime)
    try:
        run("xcrun", "simctl", "boot", device)
        run("xcrun", "simctl", "bootstatus", device, "-b")
        run("xcrun", "simctl", "status_bar", device, "override", "--time", "9:41",
            "--batteryState", "charged", "--batteryLevel", "100")
        run("xcrun", "simctl", "install", device, str(app))
        for phase, flags, name in [
            ("morning", [], "morning"), ("day", [], "day"),
            ("evening", [], "evening"), ("night", ["--empty"], "night-empty"),
            ("day", ["--large"], "day-large-type")
        ]:
            run("xcrun", "simctl", "ui", device, "appearance", "dark" if phase in ["evening", "night"] else "light")
            run("xcrun", "simctl", "launch", "--terminate-running-process", device, identifier,
                f"--phase={phase}", *flags)
            time.sleep(3)
            run("xcrun", "simctl", "io", device, "screenshot", str(OUTPUT / f"{name}.png"))
            print(f"Rendered {name}", flush=True)
    finally:
        subprocess.run(["xcrun", "simctl", "shutdown", device], check=False)
        subprocess.run(["xcrun", "simctl", "delete", device], check=False)

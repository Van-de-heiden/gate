import Combine
import SwiftUI

extension GateDayPhase {
    var isDark: Bool { self == .evening || self == .night }
    var sky: [Color] {
        switch self {
        case .morning: return [Color(red: 0.57, green: 0.77, blue: 0.88), Color(red: 1, green: 0.87, blue: 0.65)]
        case .day: return [Color(red: 0.36, green: 0.70, blue: 0.94), Color(red: 0.85, green: 0.94, blue: 0.90)]
        case .evening: return [Color(red: 0.15, green: 0.21, blue: 0.42), Color(red: 0.71, green: 0.43, blue: 0.43)]
        case .night: return [Color(red: 0.035, green: 0.075, blue: 0.20), Color(red: 0.15, green: 0.25, blue: 0.43)]
        }
    }
    var greeting: String {
        switch self {
        case .morning: return "Guten Morgen."
        case .day: return "Ein guter Moment."
        case .evening: return "Lass den Tag ruhiger werden."
        case .night: return "Ein bisschen Ruhe."
        }
    }
}

private struct DayPhaseKey: EnvironmentKey { static let defaultValue = GateDayPhase.at(Date()) }
extension EnvironmentValues {
    var gateDayPhase: GateDayPhase {
        get { self[DayPhaseKey.self] }
        set { self[DayPhaseKey.self] = newValue }
    }
}

struct GateAtmosphere: ViewModifier {
    func body(content: Content) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let phase = GateDayPhase.at(timeline.date)
            content.environment(\.gateDayPhase, phase)
                .preferredColorScheme(phase.isDark ? .dark : .light)
                .fontDesign(.rounded).tint(GateDesign.accent)
        }
    }
}

extension View {
    func gateBackground() -> some View { background(GatePageBackground()) }
}

private struct GatePageBackground: View {
    @Environment(\.gateDayPhase) private var phase
    var body: some View {
        ZStack(alignment: .top) {
            GateDesign.paper
            LinearGradient(colors: [phase.sky[0].opacity(phase.isDark ? 0.5 : 0.22), .clear],
                           startPoint: .top, endPoint: .bottom).frame(height: 450)
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

/// Decorative landscape only. Lesson photographs and charts come from cited publishers.
/// The renderer stops completely when hidden, backgrounded, in Low Power Mode or Reduce Motion.
struct GateLandscape: View {
    var active = true
    @Environment(\.gateDayPhase) private var phase
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0,
                                paused: !active || !visible || scenePhase != .active || reduceMotion || lowPower)) { timeline in
            let time = reduceMotion || lowPower ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in draw(context, size: size, time: time) }
        }
        .frame(height: 205)
        .background(LinearGradient(colors: phase.sky, startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .accessibilityHidden(true)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private func draw(_ context: GraphicsContext, size: CGSize, time: Double) {
        let w = size.width, h = size.height
        if phase == .night || phase == .evening {
            for i in 0..<38 {
                let x = CGFloat((i * 73 + 19) % 997) / 997 * w
                let y = CGFloat((i * 127 + 31) % 701) / 701 * h * 0.65
                let radius: CGFloat = i % 5 == 0 ? 1.5 : 0.8
                let alpha = (phase == .night ? 0.65 : 0.25) + 0.16 * sin(time * 0.55 + Double(i))
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                             with: .color(.white.opacity(alpha)))
            }
        }
        let orb = CGRect(x: w * 0.73, y: h * 0.18, width: 40, height: 40)
        context.fill(Path(ellipseIn: orb.insetBy(dx: -13, dy: -13)), with: .color(.white.opacity(0.06)))
        context.fill(Path(ellipseIn: orb.insetBy(dx: -6, dy: -6)), with: .color(.white.opacity(0.1)))
        context.fill(Path(ellipseIn: orb), with: .color(phase == .night ? Color(red: 0.91, green: 0.94, blue: 0.99) : Color(red: 1, green: 0.89, blue: 0.57)))
        if phase == .night {
            context.fill(Path(ellipseIn: orb.offsetBy(dx: 12, dy: -7)), with: .color(phase.sky[0]))
        } else {
            for i in 0..<3 {
                let drift = CGFloat(sin(time * 0.025 + Double(i) * 2)) * 14
                let x = w * (0.1 + CGFloat(i) * 0.30) + drift
                let y = h * (0.22 + CGFloat(i % 2) * 0.17)
                var cloud = Path()
                cloud.addEllipse(in: CGRect(x: x, y: y, width: 65, height: 18))
                cloud.addEllipse(in: CGRect(x: x + 15, y: y - 10, width: 30, height: 26))
                context.fill(cloud, with: .color(.white.opacity(phase.isDark ? 0.15 : 0.48)))
            }
        }
        let back = phase.isDark ? Color(red: 0.12, green: 0.30, blue: 0.32) : Color(red: 0.40, green: 0.65, blue: 0.43)
        let front = phase.isDark ? Color(red: 0.075, green: 0.23, blue: 0.25) : Color(red: 0.24, green: 0.52, blue: 0.35)
        var hill = Path()
        hill.move(to: CGPoint(x: 0, y: h * 0.76))
        hill.addCurve(to: CGPoint(x: w, y: h * 0.72), control1: CGPoint(x: w * 0.3, y: h * 0.41), control2: CGPoint(x: w * 0.65, y: h * 0.89))
        hill.addLine(to: CGPoint(x: w, y: h)); hill.addLine(to: CGPoint(x: 0, y: h)); hill.closeSubpath()
        context.fill(hill, with: .color(back))
        var meadow = Path()
        meadow.move(to: CGPoint(x: 0, y: h * 0.88))
        meadow.addQuadCurve(to: CGPoint(x: w, y: h * 0.8), control: CGPoint(x: w * 0.65, y: h * 0.62))
        meadow.addLine(to: CGPoint(x: w, y: h)); meadow.addLine(to: CGPoint(x: 0, y: h)); meadow.closeSubpath()
        context.fill(meadow, with: .color(front))
        let treeX = w * 0.23, treeY = h * 0.7
        var trunk = Path()
        trunk.move(to: CGPoint(x: treeX, y: treeY + 22)); trunk.addLine(to: CGPoint(x: treeX, y: treeY - 33))
        context.stroke(trunk, with: .color(phase.isDark ? Color(red: 0.13, green: 0.22, blue: 0.24) : Color(red: 0.37, green: 0.29, blue: 0.22)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        let sway = CGFloat(sin(time * 0.45)) * 1.5
        for (dx, dy, radius) in [(-17.0, -30.0, 25.0), (15.0, -34.0, 27.0), (0.0, -54.0, 25.0)] {
            context.fill(Path(ellipseIn: CGRect(x: treeX + dx + sway - radius, y: treeY + dy - radius, width: radius * 2, height: radius * 2)),
                         with: .color(phase.isDark ? Color(red: 0.12, green: 0.35, blue: 0.32) : Color(red: 0.22, green: 0.47, blue: 0.32)))
        }
    }
}

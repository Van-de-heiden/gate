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

    var landscapeSky: [Color] {
        switch self {
        case .morning: return [Color(red: 0.72, green: 0.83, blue: 0.91), Color(red: 1, green: 0.89, blue: 0.72)]
        case .day: return [Color(red: 0.58, green: 0.80, blue: 0.93), Color(red: 0.88, green: 0.96, blue: 0.92)]
        case .evening: return [Color(red: 0.15, green: 0.21, blue: 0.36), Color(red: 0.63, green: 0.40, blue: 0.42)]
        case .night: return sky
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

/// A full-bleed, stationary landscape. Its only clock is GateAtmosphere's minute
/// schedule; there is no per-frame timer, drifting scenery or simulated weather.
struct GateLandscape: View {
    @Environment(\.gateDayPhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            ZStack {
                LinearGradient(colors: phase.landscapeSky, startPoint: .top, endPoint: .bottom)
                Canvas { context, size in draw(context, size: size) }
                // Ground mist provides one continuous reading surface, without cards.
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: GateDesign.paper.opacity(0.08), location: 0.48),
                    .init(color: GateDesign.paper.opacity(0.35), location: 0.59),
                    .init(color: GateDesign.paper.opacity(0.84), location: 0.77),
                    .init(color: GateDesign.paper.opacity(0.96), location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }.id(phase).transition(.opacity)
            if reduceTransparency || contrast == .increased {
                GateDesign.paper.opacity(phase.isDark ? 0.38 : 0.45)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.5), value: phase)
        .accessibilityHidden(true).allowsHitTesting(false)
    }

    private func draw(_ context: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        if phase == .night || phase == .evening {
            for i in 0..<38 {
                let x = CGFloat((i * 73 + 19) % 997) / 997 * w
                let y = CGFloat((i * 127 + 31) % 701) / 701 * h * 0.54
                let radius: CGFloat = i % 5 == 0 ? 1.5 : 0.8
                let alpha = phase == .night ? 0.65 : 0.22
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                             with: .color(.white.opacity(alpha)))
            }
        }
        let orbY: CGFloat = phase == .morning ? 0.21 : phase == .evening ? 0.27 : 0.16
        let orb = CGRect(x: w * 0.78, y: h * orbY, width: 44, height: 44)
        context.fill(Path(ellipseIn: orb.insetBy(dx: -13, dy: -13)), with: .color(.white.opacity(0.06)))
        context.fill(Path(ellipseIn: orb.insetBy(dx: -6, dy: -6)), with: .color(.white.opacity(0.1)))
        context.fill(Path(ellipseIn: orb), with: .color(phase == .night ? Color(red: 0.91, green: 0.94, blue: 0.99) : Color(red: 1, green: 0.89, blue: 0.57)))
        if phase == .night {
            context.fill(Path(ellipseIn: orb.offsetBy(dx: 12, dy: -7)), with: .color(phase.landscapeSky[0]))
        } else {
            for i in 0..<3 {
                let x = w * (0.06 + CGFloat(i) * 0.34)
                let y = h * (0.25 + CGFloat(i % 2) * 0.05)
                var cloud = Path()
                cloud.addEllipse(in: CGRect(x: x, y: y, width: 65, height: 18))
                cloud.addEllipse(in: CGRect(x: x + 15, y: y - 10, width: 30, height: 26))
                context.fill(cloud, with: .color(.white.opacity(phase.isDark ? 0.12 : 0.30)))
            }
        }
        let back = phase.isDark ? Color(red: 0.12, green: 0.30, blue: 0.32) : Color(red: 0.40, green: 0.65, blue: 0.43)
        let front = phase.isDark ? Color(red: 0.075, green: 0.23, blue: 0.25) : Color(red: 0.24, green: 0.52, blue: 0.35)
        var hill = Path()
        hill.move(to: CGPoint(x: 0, y: h * 0.66))
        hill.addCurve(to: CGPoint(x: w, y: h * 0.69), control1: CGPoint(x: w * 0.3, y: h * 0.49), control2: CGPoint(x: w * 0.65, y: h * 0.76))
        hill.addLine(to: CGPoint(x: w, y: h)); hill.addLine(to: CGPoint(x: 0, y: h)); hill.closeSubpath()
        context.fill(hill, with: .color(back))
        var meadow = Path()
        meadow.move(to: CGPoint(x: 0, y: h * 0.75))
        meadow.addQuadCurve(to: CGPoint(x: w, y: h * 0.73), control: CGPoint(x: w * 0.65, y: h * 0.58))
        meadow.addLine(to: CGPoint(x: w, y: h)); meadow.addLine(to: CGPoint(x: 0, y: h)); meadow.closeSubpath()
        context.fill(meadow, with: .color(front))
        let treeX = w * 0.13, treeY = h * 0.64
        var trunk = Path()
        trunk.move(to: CGPoint(x: treeX, y: treeY + 22)); trunk.addLine(to: CGPoint(x: treeX, y: treeY - 33))
        context.stroke(trunk, with: .color(phase.isDark ? Color(red: 0.13, green: 0.22, blue: 0.24) : Color(red: 0.37, green: 0.29, blue: 0.22)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        for (dx, dy, radius) in [(-17.0, -30.0, 25.0), (15.0, -34.0, 27.0), (0.0, -54.0, 25.0)] {
            context.fill(Path(ellipseIn: CGRect(x: treeX + dx - radius, y: treeY + dy - radius, width: radius * 2, height: radius * 2)),
                         with: .color(phase.isDark ? Color(red: 0.12, green: 0.35, blue: 0.32) : Color(red: 0.22, green: 0.47, blue: 0.32)))
        }
    }
}

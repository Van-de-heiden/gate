import SwiftUI

/// A fuel-style dial for the last confirmed allowance, never a running countdown.
struct AllowanceGauge: View {
    let remainingMinutes: Int
    let totalMinutes: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 48

    private var capacity: Int { max(0, totalMinutes) }
    private var remaining: Int { min(capacity, max(0, remainingMinutes)) }
    private var fraction: Double { Double(remaining) / Double(max(1, capacity)) }

    var body: some View {
        VStack(spacing: 12) {
            dial
                .aspectRatio(1.85, contentMode: .fit)
                .frame(maxWidth: 320)
                .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(remaining == 0 ? "0" : "≤ \(remaining)")
                    .font(.system(size: numberSize, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text("min frei").font(.subheadline).foregroundStyle(.secondary)
            }
            Text(remaining == 0 ? "Für weitere Zeit beginnt eine Lektion." : "Von \(capacity) freien Minuten heute")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: remaining)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: capacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Freie Tageszeit")
        .accessibilityValue(remaining == 0 ? "Keine freien Minuten übrig" : "Höchstens \(remaining) von \(capacity) Minuten frei")
        .accessibilityHint("Stand der letzten iOS-Nutzungsmeldung.")
    }

    private var dial: some View {
        GeometryReader { proxy in
            let geometry = FuelDialGeometry(size: proxy.size)
            ZStack {
                FuelDialArc(fraction: 1)
                    .stroke(GateDesign.line, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                FuelDialArc(fraction: fraction)
                    .stroke(Color.primary.opacity(0.65), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .opacity(remaining == 0 ? 0 : 1)
                FuelDialTicks()
                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                Text("½").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    .position(x: geometry.center.x, y: geometry.center.y - geometry.radius - 12)
                Text("LEER").font(.system(size: 10, weight: .semibold)).tracking(1)
                    .foregroundStyle(.secondary)
                    .position(x: geometry.center.x - geometry.radius + 14, y: geometry.center.y + 16)
                Text("VOLL").font(.system(size: 10, weight: .semibold)).tracking(1)
                    .foregroundStyle(.secondary)
                    .position(x: geometry.center.x + geometry.radius - 14, y: geometry.center.y + 16)

                FuelDialNeedle()
                    .fill(Color.primary)
                    .frame(width: 7, height: geometry.needleLength)
                    .offset(y: -geometry.needleLength / 2)
                    .rotationEffect(.degrees(fraction * 180 - 90))
                    .position(geometry.center)
                Circle().fill(GateDesign.surface)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.primary, lineWidth: 4))
                    .position(geometry.center)
            }
        }
    }
}

private struct FuelDialGeometry {
    let radius: CGFloat
    let center: CGPoint
    var needleLength: CGFloat { max(0, radius - 36) }

    init(size: CGSize) {
        radius = max(0, min(size.width / 2 - 16, size.height - 48))
        center = CGPoint(x: size.width / 2, y: radius + 24)
    }

    func point(at fraction: Double, inset: CGFloat = 0) -> CGPoint {
        let angle = Double.pi * (1 + fraction)
        let distance = max(0, radius - inset)
        return CGPoint(x: center.x + CGFloat(cos(angle)) * distance,
                       y: center.y + CGFloat(sin(angle)) * distance)
    }
}

private struct FuelDialArc: Shape {
    var fraction: Double
    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let geometry = FuelDialGeometry(size: rect.size)
        var path = Path()
        path.addArc(center: geometry.center, radius: geometry.radius,
                    startAngle: .degrees(180), endAngle: .degrees(180 + 180 * min(1, max(0, fraction))),
                    clockwise: false)
        return path
    }
}

private struct FuelDialTicks: Shape {
    func path(in rect: CGRect) -> Path {
        let geometry = FuelDialGeometry(size: rect.size)
        var path = Path()
        for tick in 0...20 {
            let fraction = Double(tick) / 20
            path.move(to: geometry.point(at: fraction, inset: 13))
            path.addLine(to: geometry.point(at: fraction, inset: tick.isMultiple(of: 5) ? 28 : 20))
        }
        return path
    }
}

private struct FuelDialNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

#Preview("Freies Tagesbudget") {
    VStack(spacing: 24) {
        AllowanceGauge(remainingMinutes: 21, totalMinutes: GateState.everydayFreeMinutes).gateCard()
        AllowanceGauge(remainingMinutes: 0, totalMinutes: GateState.everydayFreeMinutes).gateCard()
    }.padding(24).background(GateDesign.paper)
}

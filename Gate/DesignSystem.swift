import SwiftUI
import FamilyControls
import ManagedSettings

enum GateDesign {
    static let paper = adaptive(light: 0xF1F7F4, dark: 0x101D36)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1C2D49)
    static let accent = adaptive(light: 0x176C65, dark: 0x93DDCB)
    static let accentInk = adaptive(light: 0xFFFFFF, dark: 0x102D32)
    static let blue = adaptive(light: 0x346CBB, dark: 0x9DBFF5)
    static let success = adaptive(light: 0x28703F, dark: 0x9CDFAC)
    static let caution = adaptive(light: 0x986018, dark: 0xF4C77B)
    static let line = accent.opacity(0.14)

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((rgb >> 16) & 255) / 255,
                           green: CGFloat((rgb >> 8) & 255) / 255,
                           blue: CGFloat(rgb & 255) / 255, alpha: 1)
        })
    }
}

struct GateButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .foregroundStyle(prominent ? GateDesign.accentInk : GateDesign.accent)
            .background(prominent ? GateDesign.accent : GateDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(prominent ? .clear : GateDesign.line))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

extension View {
    func gateCard() -> some View {
        self.padding(22).background(GateDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(GateDesign.line.opacity(0.6)))
            .shadow(color: GateDesign.accent.opacity(0.035), radius: 20, y: 6)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(GateDesign.accent)
    }
}

struct GateSection<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { Eyebrow(text: title); content }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GateTargetLabel: View {
    let target: GateTarget
    var body: some View {
        Group {
            switch target.kind {
            case .application:
                if let token = try? PropertyListDecoder().decode(ApplicationToken.self, from: target.tokenData) {
                    Label(token).labelStyle(.titleOnly)
                } else { Text("App") }
            case .webDomain:
                if let token = try? PropertyListDecoder().decode(WebDomainToken.self, from: target.tokenData) {
                    Label(token).labelStyle(.titleOnly)
                } else { Text("Website") }
            case .category: Text("Kategorie")
            }
        }
    }
}

struct GateProgressLine: View {
    let value: Double
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(GateDesign.line)
                Capsule().fill(LinearGradient(colors: [GateDesign.accent, GateDesign.blue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }.frame(height: 6).accessibilityValue("\(Int(min(1, max(0, value)) * 100)) Prozent")
    }
}

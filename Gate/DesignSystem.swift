import SwiftUI
import FamilyControls
import ManagedSettings

enum GateDesign {
    static let paper = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let line = Color.primary.opacity(0.09)
}

struct GateButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .foregroundStyle(prominent ? GateDesign.paper : Color.primary)
            .background(prominent ? Color.primary : GateDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(prominent ? .clear : GateDesign.line))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

extension View {
    func gateCard() -> some View {
        self.padding(20).background(GateDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(GateDesign.line.opacity(0.6)))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
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
                Capsule().fill(Color.primary).frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }.frame(height: 3).accessibilityValue("\(Int(min(1, max(0, value)) * 100)) Prozent")
    }
}

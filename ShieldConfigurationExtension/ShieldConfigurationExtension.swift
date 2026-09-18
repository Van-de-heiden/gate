import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let background = UIColor(red: 25 / 255, green: 26 / 255, blue: 24 / 255, alpha: 1)
    private let primary = UIColor(red: 242 / 255, green: 239 / 255, blue: 231 / 255, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        if isProtected(application) { return protectionConfiguration() }
        return configuration(for: "Diese App")
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        if isProtected(application) { return protectionConfiguration() }
        return configuration(for: "Diese App")
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        if isProtected(webDomain) { return protectionConfiguration() }
        return configuration(for: "Diese Website")
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        if isProtected(webDomain) { return protectionConfiguration() }
        return configuration(for: "Diese Website")
    }

    private func isProtected(_ application: Application) -> Bool {
        guard let token = application.token, let data = try? PropertyListEncoder().encode(token),
              let state = try? GateSharedStore.read() else { return false }
        return GateShieldPolicy.isProtected(GateTarget(kind: .application, tokenData: data), in: state)
    }

    private func isProtected(_ domain: WebDomain) -> Bool {
        guard let token = domain.token, let data = try? PropertyListEncoder().encode(token),
              let state = try? GateSharedStore.read() else { return false }
        return GateShieldPolicy.isProtected(GateTarget(kind: .webDomain, tokenData: data), in: state)
    }

    private func protectionConfiguration() -> ShieldConfiguration {
        let messages = [
            ("Ein Impuls ist kein Auftrag.", "Du hast diese Grenze für dich gewählt. Du kannst den Drang bemerken, ohne ihm zu folgen."),
            ("Dein nächster Schritt gehört dir.", "Leg das Handy kurz weg. Ein Glas Wasser, ein paar Schritte oder eine Nachricht an jemanden können ein Anfang sein."),
            ("Du darfst hier aufhören.", "Du musst den Impuls nicht wegdrücken. Lass ihn da sein und entscheide dich für deinen nächsten kleinen Schritt."),
            ("Erinnere dich an dein Warum.", "Was wolltest du mit dieser Zeit eigentlich machen? Eine kleine Handlung für dieses Vorhaben reicht jetzt."),
            ("Zurück zu deiner Absicht.", "Dieser Moment entscheidet nicht über deinen Wert. Du kannst jetzt eine Entscheidung treffen, die zu deinem Plan passt.")
        ]
        let message = messages[messageIndex(count: messages.count)]
        return ShieldConfiguration(backgroundBlurStyle: nil, backgroundColor: background,
            icon: portalIcon,
            title: .init(text: "gate\n\n\(message.0)", color: primary),
            subtitle: .init(text: "\(message.1)\n\nKeine Freigabe. Deine Grenze bleibt.", color: primary.withAlphaComponent(0.78)),
            primaryButtonLabel: .init(text: "Pause in Gate anfordern", color: background),
            primaryButtonBackgroundColor: primary,
            secondaryButtonLabel: .init(text: "Heute nicht", color: primary))
    }

    private func configuration(for subject: String) -> ShieldConfiguration {
        let messages = ["Erst verstehen. Dann weiter.", "Ein guter Gedanke vor dem nächsten Feed.",
                        "Deine Zeit verdient eine bewusste Wahl.", "Ein Moment für dein Wissen."]
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: background,
            icon: portalIcon,
            title: ShieldConfiguration.Label(
                text: "gate\n\n\(messages[messageIndex(count: messages.count)])",
                color: primary
            ),
            subtitle: ShieldConfiguration.Label(
                text: "\(subject) wartet. Eine kurze Lektion öffnet dir wieder etwas Zeit.\n\nFordere sie an und öffne danach die Gate-Mitteilung oder Gate selbst.",
                color: primary.withAlphaComponent(0.78)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Lektion anfordern",
                color: background
            ),
            primaryButtonBackgroundColor: primary,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Zurück zum Wesentlichen",
                color: primary
            )
        )
    }

    // Changes only when iOS asks for a new configuration. No browsing history or attempt counter.
    private func messageIndex(count: Int) -> Int {
        Int(max(0, Date().timeIntervalSince1970) / 1800) % count
    }

    // Native rendering of docs/brand/gate-icon.svg, independent of the main app's asset bundle.
    private var portalIcon: UIImage {
        let size = CGSize(width: 80, height: 80)
        return UIGraphicsImageRenderer(size: size).image { renderer in
            let context = renderer.cgContext
            context.scaleBy(x: size.width / 1024, y: size.height / 1024)
            primary.setStroke()
            primary.setFill()
            let arch = UIBezierPath()
            arch.move(to: CGPoint(x: 304, y: 756))
            arch.addLine(to: CGPoint(x: 304, y: 436))
            arch.addCurve(to: CGPoint(x: 512, y: 228), controlPoint1: CGPoint(x: 304, y: 321.1), controlPoint2: CGPoint(x: 397.1, y: 228))
            arch.addCurve(to: CGPoint(x: 720, y: 436), controlPoint1: CGPoint(x: 626.9, y: 228), controlPoint2: CGPoint(x: 720, y: 321.1))
            arch.addLine(to: CGPoint(x: 720, y: 756))
            arch.lineWidth = 64
            arch.lineCapStyle = .square
            arch.stroke()
            let door = UIBezierPath()
            door.move(to: CGPoint(x: 496, y: 427))
            door.addLine(to: CGPoint(x: 620, y: 380))
            door.addLine(to: CGPoint(x: 620, y: 711))
            door.addLine(to: CGPoint(x: 496, y: 758))
            door.close()
            door.fill()
        }.withRenderingMode(.alwaysOriginal)
    }
}

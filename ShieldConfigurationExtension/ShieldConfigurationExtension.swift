import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let background = UIColor(white: 0.055, alpha: 1)
    private let primary = UIColor(white: 0.96, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration(for: "Diese App")
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        configuration(for: "Diese App")
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

    private func isProtected(_ domain: WebDomain) -> Bool {
        guard let token = domain.token, let data = try? PropertyListEncoder().encode(token),
              let state = try? GateSharedStore.read() else { return false }
        return GateShieldPolicy.isProtected(GateTarget(kind: .webDomain, tokenData: data), in: state)
    }

    private func protectionConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(backgroundBlurStyle: .systemUltraThinMaterialDark, backgroundColor: background,
            icon: UIImage(systemName: "hand.raised"),
            title: .init(text: "Du hast diese Grenze bewusst gesetzt.", color: .white),
            subtitle: .init(text: "Aus einem kurzen Impuls kann mehr Zeit werden als geplant. Diese Website bleibt geschützt. Schliess den Tab oder öffne die Gate-Mitteilung: 60 Sekunden Abstand, dann ein guter nächster Schritt.", color: primary),
            primaryButtonLabel: .init(text: "Abstand gewinnen", color: background),
            primaryButtonBackgroundColor: primary,
            secondaryButtonLabel: .init(text: "Tab schliessen", color: .white))
    }

    private func configuration(for subject: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: background,
            icon: nil,
            title: ShieldConfiguration.Label(
                text: "Erst verstehen. Dann weiter.",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "\(subject) ist gesperrt. Fordere eine Lektion an und öffne die Gate-Mitteilung. Du kannst Gate auch selbst öffnen. Andere Freigaben bleiben unabhängig.",
                color: UIColor.white.withAlphaComponent(0.72)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Lektion anfordern",
                color: background
            ),
            primaryButtonBackgroundColor: primary,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Zurück zum Wesentlichen",
                color: .white
            )
        )
    }
}

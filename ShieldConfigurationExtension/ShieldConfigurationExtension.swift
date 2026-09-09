import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let background = UIColor(red: 0.055, green: 0.055, blue: 0.06, alpha: 1)
    private let primary = UIColor(red: 0.92, green: 0.92, blue: 0.89, alpha: 1)

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
        configuration(for: "Diese Website")
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        configuration(for: "Diese Website")
    }

    private func configuration(for subject: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: background,
            icon: UIImage(systemName: "lock.shield"),
            title: ShieldConfiguration.Label(
                text: "Die freie Zeit ist aufgebraucht.",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "\(subject) verlangt nun eine kurze Lektion. Der Inhaltsfilter bleibt ohne Ausnahme aktiv.",
                color: UIColor.white.withAlphaComponent(0.72)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Freischaltung vorbereiten",
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


import ManagedSettings
import ManagedSettingsUI
import UIKit

// A shield only ever shows once spendable balance has actually run out — AppStore
// proactively removes the shield from blocked apps whenever there's spendable balance
// (see AppStore.syncShieldToSpendableBalance), so this never needs to offer a spend action.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            title: ShieldConfiguration.Label(text: "Blocked", color: .white),
            subtitle: ShieldConfiguration.Label(text: "Open Bank to earn more time", color: .gray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .white),
            primaryButtonBackgroundColor: .darkGray
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: .black,
            title: ShieldConfiguration.Label(text: "Blocked", color: .white),
            subtitle: ShieldConfiguration.Label(text: "Open Bank to earn more time", color: .gray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .white),
            primaryButtonBackgroundColor: .darkGray
        )
    }
}

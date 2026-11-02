import ManagedSettings

// Blocked apps are unshielded proactively by AppStore whenever there's spendable balance
// (see AppStore.syncShieldToSpendableBalance), not by a button on the shield — so by the
// time a shield is actually shown, there's nothing left to grant. This just dismisses it.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
}

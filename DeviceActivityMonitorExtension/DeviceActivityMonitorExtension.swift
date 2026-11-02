import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()
    private let defaults = UserDefaults(suiteName: "group.com.anushriadhia.bank") ?? .standard

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        BankLog.monitoring.notice("intervalDidStart: \(activity.rawValue)")
    }

    // The real stop signal: fires once actual usage of the blocked apps reaches the
    // spendable threshold set when the session started.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        BankLog.monitoring.notice("eventDidReachThreshold: \(event.rawValue) in \(activity.rawValue)")
        guard activity == .scrolling, event == .balanceThreshold else { return }
        endSpendingSession()
    }

    // Backstop only, in case the threshold event never fires — the monitoring window set
    // in AppStore.scheduleUsageThresholdMonitoring ends at midnight, when the daily unlock
    // resets anyway, so this firing is not expected to be the normal path.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        BankLog.monitoring.notice("intervalDidEnd: \(activity.rawValue)")
        guard activity == .scrolling else { return }
        endSpendingSession()
    }

    private func endSpendingSession() {
        guard defaults.bool(forKey: "scrolling") else {
            BankLog.monitoring.notice("No spending session in shared defaults; nothing to end")
            return
        }

        reapplyShield()
        // Floor at the unlock reserve (balanceAtScrollStart - spendableAtScrollStart), not
        // zero — the reserve was never spendable, so this lands bank display at exactly
        // "00:00" rather than overshooting into negative unlock-debt territory.
        let balanceAtScrollStart = defaults.integer(forKey: "balanceAtScrollStart")
        let spendableAtScrollStart = defaults.integer(forKey: "spendableAtScrollStart")
        defaults.set(false, forKey: "scrolling")
        defaults.set(balanceAtScrollStart - spendableAtScrollStart, forKey: "balance")
        DeviceActivityCenter().stopMonitoring([.scrolling])
    }

    private func reapplyShield() {
        guard let data = defaults.data(forKey: "selectedApps"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            BankLog.monitoring.error("Couldn't read selectedApps from shared defaults; shield not reapplied")
            return
        }
        let applications = selection.applicationTokens
        let categories = selection.categoryTokens
        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    }
}

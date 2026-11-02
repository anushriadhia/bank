import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity
import ActivityKit
import Combine

final class AppStore: ObservableObject {
    private let defaults = UserDefaults(suiteName: "group.com.anushriadhia.bank") ?? .standard
    private let settingsStore = ManagedSettingsStore()

    @Published var balance: Int = 0        // total earned seconds
    @Published var dailyFocusSeconds: Int = 0
    @Published var log: [Session] = []
    @Published var authorized: Bool = false

    @Published var focusRunning: Bool = false
    @Published var focusElapsed: Int = 0

    @Published var activities: [String] = []
    @Published var selectedActivity: String? = nil

    @Published var scrolling: Bool = false

    @Published var selectedApps = FamilyActivitySelection()

    private var focusStartDate: Date?
    private var scrollStartDate: Date?
    private var balanceAtScrollStart: Int = 0
    private var spendableAtScrollStart: Int = 0

    private var displayTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var currentActivity: Activity<BankActivityAttributes>?

    // What the bank display shows: negative while paying unlock debt, positive when spendable.
    // Uses the fixed threshold (not the shrinking `debt`) so each focused second moves the
    // display by exactly one second — subtracting `debt` here would double-count, since debt
    // already falls by one for every second `balance` rises.
    var bankDisplay: Int { balance - BankSpending.dailyUnlockThreshold }

    var unlocked: Bool { BankSpending.isUnlocked(dailyFocusSeconds: dailyFocusSeconds) }

    init() {
        load()

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.syncOnForeground() }
            .store(in: &cancellables)
    }

    // MARK: - Authorization

    func requestAuthorization() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run {
                    self.authorized = true
                    // `load()` already ran before this completed (authorization is
                    // requested async from BankApp's onAppear, after AppStore.init), so
                    // the authorized-dependent setup it skipped has to happen here instead
                    // — otherwise a blocked app with spendable balance just stays shielded
                    // until some unrelated foreground/focus event happens to trigger a sync.
                    self.syncAuthorizedState()
                }
            } catch {
                await MainActor.run { self.authorized = false }
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        // Sessions now run almost entirely while this process is backgrounded (the user is
        // in the blocked app, not Bank), so it's likely to be killed and relaunched
        // mid-session — recover the in-flight Live Activity reference ActivityKit itself
        // still tracks, or a later endActivity() would have nothing to end and orphan it.
        currentActivity = Activity<BankActivityAttributes>.activities.first

        if let data = defaults.data(forKey: "log"),
           let decoded = try? JSONDecoder().decode([Session].self, from: data) {
            log = decoded
        }

        if let data = defaults.data(forKey: "dailyFocus"),
           let decoded = try? JSONDecoder().decode(DailyFocus.self, from: data),
           decoded.date == Self.todayKey() {
            dailyFocusSeconds = decoded.seconds
        }

        activities = defaults.stringArray(forKey: "activities") ?? []

        refreshFromSharedState()
        syncAuthorizedState()
    }

    // Picks up a spending session ending while this process wasn't running —
    // DeviceActivityMonitorExtension clears `scrolling` and lowers `balance` in shared
    // defaults once usage reaches the spendable amount, since it runs in a separate process
    // and can only communicate via shared UserDefaults. Called on cold launch and whenever
    // the app returns to the foreground.
    private func refreshFromSharedState() {
        balance = defaults.integer(forKey: "balance")
        scrolling = defaults.bool(forKey: "scrolling")
        if scrolling {
            scrollStartDate = Date(timeIntervalSince1970: defaults.double(forKey: "scrollStartDate"))
            balanceAtScrollStart = defaults.integer(forKey: "balanceAtScrollStart")
            spendableAtScrollStart = defaults.integer(forKey: "spendableAtScrollStart")
        } else {
            scrollStartDate = nil
        }

        syncWithClock()
    }

    private func syncOnForeground() {
        refreshFromSharedState()
        syncAuthorizedState()
    }

    // Everything that depends on Screen Time authorization having actually succeeded:
    // picking up the saved app selection and syncing the shield to it. Called after load()
    // and on every foreground, but since authorization itself completes asynchronously
    // (see requestAuthorization()), it also has to be called the moment that finishes.
    private func syncAuthorizedState() {
        guard authorized else { return }
        if let data = defaults.data(forKey: "selectedApps"),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selectedApps = decoded
        }
        syncShieldToSpendableBalance()
    }

    private func save() {
        defaults.set(balance, forKey: "balance")
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: "log")
        }
        let daily = DailyFocus(date: Self.todayKey(), seconds: dailyFocusSeconds)
        if let data = try? JSONEncoder().encode(daily) {
            defaults.set(data, forKey: "dailyFocus")
        }
    }

    func saveSelectedApps() {
        if let data = try? JSONEncoder().encode(selectedApps) {
            defaults.set(data, forKey: "selectedApps")
        }
        syncShieldToSpendableBalance()
    }

    // MARK: - Shield management

    func applyShield() {
        guard authorized else { return }
        let applications = selectedApps.applicationTokens
        let categories = selectedApps.categoryTokens
        if applications.isEmpty && categories.isEmpty { return }
        settingsStore.shield.applications = applications.isEmpty ? nil : applications
        settingsStore.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    }

    func removeShield() {
        guard authorized else { return }
        settingsStore.shield.applications = nil
        settingsStore.shield.applicationCategories = nil
    }

    // There's no "open the app" button — a blocked app should open immediately whenever
    // there's spendable balance. So instead of waiting for a shield tap, this proactively
    // keeps the shield in sync with spendability: unshields and starts usage-threshold
    // monitoring the moment balance becomes spendable, and makes sure the shield is up
    // whenever it isn't. Called on launch, on foreground, after a focus session ends, and
    // after the blocked-apps selection changes.
    private func syncShieldToSpendableBalance() {
        guard authorized else { return }
        let spendable = BankSpending.spendableSeconds(balance: balance, dailyFocusSeconds: dailyFocusSeconds)

        switch ShieldSync.action(spendable: spendable, scrolling: scrolling, focusRunning: focusRunning) {
        case .leaveShieldedForFocus:
            break
        case .startSpending:
            startSpendableSession(spendable: spendable)
        case .keepSpending:
            removeShield()
        case .endSpending:
            stopScrolling()
        case .shield:
            applyShield()
        }
    }

    private func startSpendableSession(spendable: Int) {
        scrolling = true
        scrollStartDate = Date()
        balanceAtScrollStart = balance
        spendableAtScrollStart = spendable
        defaults.set(true, forKey: "scrolling")
        defaults.set(scrollStartDate!.timeIntervalSince1970, forKey: "scrollStartDate")
        defaults.set(balanceAtScrollStart, forKey: "balanceAtScrollStart")
        defaults.set(spendableAtScrollStart, forKey: "spendableAtScrollStart")

        removeShield()
        startLiveActivity(kind: .scrolling, start: scrollStartDate!)
        scheduleUsageThresholdMonitoring(afterSeconds: spendable)
    }

    // The monitoring window runs from now until the end of today. It ends at midnight because
    // that's when the daily unlock resets and spendable balance disappears anyway — and
    // because a window that wraps past midnight isn't expressible reliably with time-of-day
    // components alone. DeviceActivityCenter rejects windows under 15 minutes
    // (MonitoringError.intervalTooShort), so close to midnight the start moves earlier just
    // enough to keep that minimum. The real stop signal is the usage threshold event;
    // DeviceActivityMonitorExtension's `intervalDidEnd` is only a backstop.
    private static let minimumMonitoringWindow: TimeInterval = 16 * 60 // Apple's minimum is 15

    private func scheduleUsageThresholdMonitoring(afterSeconds spendable: Int) {
        let calendar = Calendar.current
        let now = Date()
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        let start = min(now, endOfToday.addingTimeInterval(-Self.minimumMonitoringWindow))

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: start),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: endOfToday),
            repeats: false
        )

        let event = Self.spendingEvent(for: selectedApps, thresholdSeconds: spendable)

        let center = DeviceActivityCenter()
        center.stopMonitoring([.scrolling])
        do {
            try center.startMonitoring(.scrolling, during: schedule, events: [.balanceThreshold: event])
            let appCount = selectedApps.applicationTokens.count
            let categoryCount = selectedApps.categoryTokens.count
            let activeNames = center.activities.map(\.rawValue)
            BankLog.monitoring.notice("Started usage monitoring: threshold \(spendable)s, \(appCount) apps, \(categoryCount) categories, active: \(activeNames)")
        } catch {
            // Without monitoring nothing will ever re-shield, so this must not fail silently.
            BankLog.monitoring.error("startMonitoring failed: \(String(describing: error))")
        }
    }

    // Only usage from now on counts toward the threshold — that's what "spend from now"
    // means. iOS 17.4+ lets this be stated explicitly; earlier versions only have the
    // initializer without it.
    private static func spendingEvent(for selection: FamilyActivitySelection, thresholdSeconds: Int) -> DeviceActivityEvent {
        let threshold = DateComponents(second: thresholdSeconds)
        if #available(iOS 17.4, *) {
            return DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: threshold,
                includesPastActivity: false
            )
        }
        return DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: threshold
        )
    }

    // MARK: - Clock sync

    private func syncWithClock() {
        if focusRunning, let start = focusStartDate {
            focusElapsed = Int(Date().timeIntervalSince(start))
        }
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.syncWithClock() }
        }
    }

    private func stopDisplayTimer() {
        if !focusRunning {
            displayTimer?.invalidate()
            displayTimer = nil
        }
    }

    // MARK: - Focus timer

    func toggleFocus() {
        focusRunning ? stopFocus() : startFocus()
    }

    private func startFocus() {
        // Focus re-shields the apps, so a spending session can't stay open underneath it —
        // otherwise `scrolling` would claim the apps are unshielded when they aren't. Ending
        // it here means stopFocus's sync starts a fresh session with the updated balance.
        if scrolling { stopScrolling() }
        focusElapsed = 0
        focusStartDate = Date()
        focusRunning = true
        applyShield()
        startLiveActivity(kind: .focus, start: focusStartDate!)
        startDisplayTimer()
    }

    private func stopFocus() {
        focusRunning = false
        syncWithClock()
        focusStartDate = nil
        endActivity()

        // Credit all elapsed seconds (not just whole minutes) so bank display is smooth
        let earned = focusElapsed
        dailyFocusSeconds += earned
        balance += earned

        if earned > 0 {
            let session = Session(date: Date(), durationSeconds: earned, earnedMinutes: earned / 60, activity: selectedActivity)
            log.insert(session, at: 0)
        }

        save()
        focusElapsed = 0
        stopDisplayTimer()

        // Earning may have just made balance spendable for the first time today — this is
        // the only place that can happen while the app is running, since the daily unlock
        // gate is checked live here.
        syncShieldToSpendableBalance()
    }

    // MARK: - Scrolling (spending)

    // Spending sessions are started proactively by syncShieldToSpendableBalance(), not by
    // any user action — this just ends one, either because the daily unlock reset made the
    // balance unspendable again (via syncShieldToSpendableBalance) or because a focus
    // session is starting (via startFocus).
    private func stopScrolling() {
        scrolling = false
        scrollStartDate = nil
        endActivity()
        applyShield()
        save()
        defaults.set(false, forKey: "scrolling")
        DeviceActivityCenter().stopMonitoring([.scrolling])
        stopDisplayTimer()
    }

    // MARK: - Activities

    func addActivity(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !activities.contains(trimmed) else { return }
        activities.append(trimmed)
        defaults.set(activities, forKey: "activities")
        selectActivity(trimmed)
    }

    func selectActivity(_ name: String?) {
        selectedActivity = name
    }

    func updateSessionActivity(sessionId: UUID, activity: String?) {
        guard let index = log.firstIndex(where: { $0.id == sessionId }) else { return }
        log[index].activity = activity
        save()
    }

    // MARK: - Live Activity

    private func startLiveActivity(kind: BankActivityAttributes.SessionKind, start: Date) {
        endActivity()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = BankActivityAttributes.ContentState(kind: kind, startDate: start)
        currentActivity = try? Activity.request(
            attributes: BankActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    private func endActivity() {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - Helpers

    static func todayKey() -> String {
        DailyFocus.todayKey()
    }
}

// The pure decision behind AppStore.syncShieldToSpendableBalance(), kept separate so it can
// be tested without Screen Time authorization.
enum ShieldSync {
    enum Action: Equatable {
        case leaveShieldedForFocus // focus keeps apps blocked; stopFocus re-syncs afterwards
        case startSpending
        case keepSpending          // session already running — make sure the shield is really down
        case endSpending           // spendable balance disappeared, e.g. the midnight reset
        case shield
    }

    static func action(spendable: Int, scrolling: Bool, focusRunning: Bool) -> Action {
        if focusRunning { return .leaveShieldedForFocus }
        if spendable > 0 { return scrolling ? .keepSpending : .startSpending }
        return scrolling ? .endSpending : .shield
    }
}

struct Session: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let durationSeconds: Int
    let earnedMinutes: Int
    var activity: String?

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: date)
    }

    var formattedDateTime: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: date)
    }

    var formattedDuration: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}


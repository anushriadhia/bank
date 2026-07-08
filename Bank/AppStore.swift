import SwiftUI
import FamilyControls
import ManagedSettings
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

    private var displayTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var currentActivity: Activity<BankActivityAttributes>?

    private static let dailyUnlockThreshold = 900 // seconds of focus required to unlock (15 min)

    // What the bank display shows: negative while paying unlock debt, positive when spendable.
    // Uses the fixed threshold (not the shrinking `debt`) so each focused second moves the
    // display by exactly one second — subtracting `debt` here would double-count, since debt
    // already falls by one for every second `balance` rises.
    var bankDisplay: Int { balance - Self.dailyUnlockThreshold }

    var unlocked: Bool { dailyFocusSeconds >= Self.dailyUnlockThreshold }

    init() {
        load()

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.syncWithClock() }
            .store(in: &cancellables)
    }

    // MARK: - Authorization

    func requestAuthorization() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run { self.authorized = true }
            } catch {
                await MainActor.run { self.authorized = false }
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        balance = defaults.integer(forKey: "balance")

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
        selectedActivity = defaults.string(forKey: "lastActivity")

        if authorized {
            if let data = defaults.data(forKey: "selectedApps"),
               let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
                selectedApps = decoded
            }
            if !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty {
                applyShield()
            }
        }
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
        applyShield()
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

    // MARK: - Clock sync

    private func syncWithClock() {
        if focusRunning, let start = focusStartDate {
            focusElapsed = Int(Date().timeIntervalSince(start))
        }
        if scrolling, let start = scrollStartDate {
            let elapsed = Int(Date().timeIntervalSince(start))
            let newBalance = max(0, balanceAtScrollStart - elapsed)
            balance = newBalance
            defaults.set(balance, forKey: "balance")
            if newBalance <= 0 {
                stopScrolling()
            }
        }
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.syncWithClock() }
        }
    }

    private func stopDisplayTimer() {
        if !focusRunning && !scrolling {
            displayTimer?.invalidate()
            displayTimer = nil
        }
    }

    // MARK: - Focus timer

    func toggleFocus() {
        focusRunning ? stopFocus() : startFocus()
    }

    private func startFocus() {
        focusElapsed = 0
        focusStartDate = Date()
        focusRunning = true
        applyShield()
        startFocusActivity()
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
    }

    // MARK: - Scrolling (spending)

    func toggleScrolling() {
        if scrolling {
            stopScrolling()
        } else if balance > 0 && unlocked {
            startScrolling()
        }
    }

    private func startScrolling() {
        scrolling = true
        scrollStartDate = Date()
        balanceAtScrollStart = balance
        removeShield()
        // Balance is spent 1:1 per second, so the moment it hits zero is known up front.
        let activityEndDate = scrollStartDate!.addingTimeInterval(TimeInterval(balanceAtScrollStart))
        startScrollingActivity(endDate: activityEndDate)
        startDisplayTimer()
    }

    private func stopScrolling() {
        scrolling = false
        scrollStartDate = nil
        endActivity()
        applyShield()
        save()
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
        defaults.set(name, forKey: "lastActivity")
    }

    func updateSessionActivity(sessionId: UUID, activity: String?) {
        guard let index = log.firstIndex(where: { $0.id == sessionId }) else { return }
        log[index].activity = activity
        save()
    }

    // MARK: - Live Activity

    private func startFocusActivity() {
        endActivity()
        guard ActivityAuthorizationInfo().areActivitiesEnabled, let start = focusStartDate else { return }
        let state = BankActivityAttributes.ContentState(kind: .focus, startDate: start, endDate: nil)
        currentActivity = try? Activity.request(
            attributes: BankActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    private func startScrollingActivity(endDate: Date) {
        endActivity()
        guard ActivityAuthorizationInfo().areActivitiesEnabled, let start = scrollStartDate else { return }
        let state = BankActivityAttributes.ContentState(kind: .scrolling, startDate: start, endDate: endDate)
        currentActivity = try? Activity.request(
            attributes: BankActivityAttributes(),
            content: ActivityContent(state: state, staleDate: endDate),
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
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
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

struct DailyFocus: Codable {
    let date: String
    let seconds: Int
}

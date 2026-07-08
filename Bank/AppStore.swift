import SwiftUI
import FamilyControls
import ManagedSettings
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

    @Published var scrolling: Bool = false

    @Published var selectedApps = FamilyActivitySelection()

    private var focusStartDate: Date?
    private var scrollStartDate: Date?
    private var balanceAtScrollStart: Int = 0

    private var displayTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Debt = seconds still needed to unlock today
    private var debt: Int { max(0, 900 - dailyFocusSeconds - (focusRunning ? focusElapsed : 0)) }

    // What the bank display shows: negative while paying unlock debt, positive when spendable
    var bankDisplay: Int { balance - debt }

    // Unlocked once debt is paid
    var unlocked: Bool { debt == 0 }

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
        startDisplayTimer()
    }

    private func stopFocus() {
        focusRunning = false
        syncWithClock()
        focusStartDate = nil

        // Credit all elapsed seconds (not just whole minutes) so bank display is smooth
        let earned = focusElapsed
        dailyFocusSeconds += earned
        balance += earned

        if earned > 0 {
            let session = Session(date: Date(), durationSeconds: earned, earnedMinutes: earned / 60)
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
        startDisplayTimer()
    }

    private func stopScrolling() {
        scrolling = false
        scrollStartDate = nil
        applyShield()
        save()
        stopDisplayTimer()
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

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .short
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

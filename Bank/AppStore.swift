import SwiftUI
import FamilyControls
import ManagedSettings

final class AppStore: ObservableObject {
    private let defaults = UserDefaults(suiteName: "group.com.bank.app") ?? .standard
    private let settingsStore = ManagedSettingsStore()

    // balance is stored in seconds
    @Published var balance: Int = 0
    @Published var dailyFocusSeconds: Int = 0
    @Published var log: [Session] = []
    @Published var authorized: Bool = false

    @Published var focusRunning: Bool = false
    @Published var focusElapsed: Int = 0

    @Published var scrolling: Bool = false

    @Published var selectedApps = FamilyActivitySelection()

    private var focusTimer: Timer?
    private var scrollTimer: Timer?

    var unlocked: Bool { dailyFocusSeconds >= 900 }
    var secondsToUnlock: Int { max(0, 900 - dailyFocusSeconds) }

    init() {
        load()
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

        if let data = defaults.data(forKey: "selectedApps"),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selectedApps = decoded
        }

        if !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty {
            applyShield()
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
        let applications = selectedApps.applicationTokens
        let categories = selectedApps.categoryTokens
        if applications.isEmpty && categories.isEmpty { return }
        settingsStore.shield.applications = applications.isEmpty ? nil : applications
        settingsStore.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    }

    func removeShield() {
        settingsStore.shield.applications = nil
        settingsStore.shield.applicationCategories = nil
    }

    // MARK: - Focus timer

    func toggleFocus() {
        if focusRunning {
            stopFocus()
        } else {
            startFocus()
        }
    }

    private func startFocus() {
        focusElapsed = 0
        focusRunning = true
        applyShield()
        focusTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.focusElapsed += 1
            }
        }
    }

    private func stopFocus() {
        focusTimer?.invalidate()
        focusTimer = nil
        focusRunning = false

        let earnedMinutes = focusElapsed / 60
        dailyFocusSeconds += focusElapsed

        if earnedMinutes > 0 {
            balance += earnedMinutes * 60
            let session = Session(
                date: Date(),
                durationSeconds: focusElapsed,
                earnedMinutes: earnedMinutes
            )
            log.insert(session, at: 0)
        }

        save()
        focusElapsed = 0
    }

    // MARK: - Scrolling (spending)

    func toggleScrolling() {
        if scrolling {
            stopScrolling()
        } else if balance > 0 {
            startScrolling()
        }
    }

    private func startScrolling() {
        scrolling = true
        removeShield()
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.balance <= 1 {
                    self.balance = 0
                    self.stopScrolling()
                } else {
                    self.balance -= 1
                }
                self.defaults.set(self.balance, forKey: "balance")
            }
        }
    }

    private func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        scrolling = false
        applyShield()
        save()
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

import Foundation

// Single source of truth for "how much balance can actually be spent right now" — used by
// AppStore and by DeviceActivityMonitorExtension, which can't share AppStore's logic directly
// since it runs in a separate process and only sees shared UserDefaults.
enum BankSpending {
    static let dailyUnlockThreshold = 900 // seconds of focus required to unlock (15 min)

    static func isUnlocked(dailyFocusSeconds: Int) -> Bool {
        dailyFocusSeconds >= dailyUnlockThreshold
    }

    // The first `dailyUnlockThreshold` seconds of balance are the unlock reserve, not
    // spendable — only earned time beyond that, and only once today's focus minimum is
    // met, can actually be spent opening a blocked app.
    static func spendableSeconds(balance: Int, dailyFocusSeconds: Int) -> Int {
        guard isUnlocked(dailyFocusSeconds: dailyFocusSeconds) else { return 0 }
        return max(0, balance - dailyUnlockThreshold)
    }

    static func currentSpendableSeconds(defaults: UserDefaults) -> Int {
        let balance = defaults.integer(forKey: "balance")
        var dailyFocusSeconds = 0
        if let data = defaults.data(forKey: "dailyFocus"),
           let decoded = try? JSONDecoder().decode(DailyFocus.self, from: data),
           decoded.date == DailyFocus.todayKey() {
            dailyFocusSeconds = decoded.seconds
        }
        return spendableSeconds(balance: balance, dailyFocusSeconds: dailyFocusSeconds)
    }
}

struct DailyFocus: Codable {
    let date: String
    let seconds: Int

    static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

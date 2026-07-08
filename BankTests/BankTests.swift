import XCTest
@testable import Bank

final class BankTests: XCTestCase {
    var store: AppStore!

    override func setUp() {
        super.setUp()
        store = AppStore()
        store.balance = 0
        store.dailyFocusSeconds = 0
        store.log = []
    }

    // MARK: - Bank display

    func testBankDisplayStartsAtNegativeFifteenMinutes() {
        XCTAssertEqual(store.bankDisplay, -900)
    }

    func testBankDisplayReflectsPartialProgress() {
        // 5 min focused → display = 300 - 900 = -600 (10 more minutes needed)
        store.dailyFocusSeconds = 300
        store.balance = 300
        XCTAssertEqual(store.bankDisplay, -600)
    }

    func testBankDisplayIsZeroAtExactUnlock() {
        // 15 min focused → display = 900 - 900 = 0
        store.dailyFocusSeconds = 900
        store.balance = 900
        XCTAssertEqual(store.bankDisplay, 0)
    }

    func testBankDisplayIsPositiveAfterUnlock() {
        // 20 min focused → display = 1200 - 900 = 300 (5 min spendable)
        store.dailyFocusSeconds = 1200
        store.balance = 1200
        XCTAssertEqual(store.bankDisplay, 300)
    }

    // MARK: - Unlock gate

    func testNotUnlockedBelowDailyMinimum() {
        store.dailyFocusSeconds = 899
        XCTAssertFalse(store.unlocked)
    }

    func testUnlockedAtDailyMinimum() {
        store.dailyFocusSeconds = 900
        XCTAssertTrue(store.unlocked)
    }

    func testUnlockedAboveDailyMinimum() {
        store.dailyFocusSeconds = 1800
        XCTAssertTrue(store.unlocked)
    }

    // MARK: - Focus session (via store state, bypassing timers)

    func testCompletedFocusAddsToBalance() {
        // Simulate what stopFocus does: credit elapsed seconds
        let elapsed = 120
        store.balance += elapsed
        store.dailyFocusSeconds += elapsed
        store.log.insert(Session(date: Date(), durationSeconds: elapsed, earnedMinutes: elapsed / 60), at: 0)

        XCTAssertEqual(store.balance, 120)
        XCTAssertEqual(store.dailyFocusSeconds, 120)
        XCTAssertEqual(store.log.count, 1)
        XCTAssertEqual(store.log[0].earnedMinutes, 2)
    }

    func testMultipleFocusSessionsAccumulate() {
        for _ in 0..<3 {
            let elapsed = 300
            store.balance += elapsed
            store.dailyFocusSeconds += elapsed
            store.log.insert(Session(date: Date(), durationSeconds: elapsed, earnedMinutes: elapsed / 60), at: 0)
        }

        XCTAssertEqual(store.balance, 900)
        XCTAssertEqual(store.dailyFocusSeconds, 900)
        XCTAssertEqual(store.log.count, 3)
        XCTAssertTrue(store.unlocked)
    }

    func testBankDisplayAfterFullUnlockSession() {
        let elapsed = 900
        store.balance += elapsed
        store.dailyFocusSeconds += elapsed

        XCTAssertTrue(store.unlocked)
        XCTAssertEqual(store.bankDisplay, 0)
    }

    // MARK: - Today key

    func testTodayKeyMatchesCurrentDate() {
        let key = AppStore.todayKey()
        let parts = key.split(separator: "-")
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(Int(parts[0]), Calendar.current.component(.year, from: Date()))
        XCTAssertEqual(Int(parts[1]), Calendar.current.component(.month, from: Date()))
    }
}

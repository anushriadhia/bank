# Focus Bank

A screen time budgeting app for iOS. You earn minutes by focusing, then spend them using blocked apps. When your balance runs out, apps get blocked again.

## Concept

Focus Bank treats attention like currency. Focus sessions deposit minutes into your balance. Once you've hit the daily 15-minute focus minimum, your selected apps unblock automatically — no separate "withdraw" step — and the balance drains in real time while you're actually using them. When it hits zero, shields go back up. The inspiration? Personal for us, as people trying to avoid doom scrolling and work on our goals. But also a reel we saw by @queencitytrends where she said that a rule in her house is that her kids get one minute of screen time for every minute of work time. Ironic that we were inspired while doom scrolling, huh?

## Problem Thinking

Problems that we discussed: 
- It's easy to open apps that allow for time sinks in mindless activity
- Scrolling was affecting our attention and ability to spend time on things we enjoy or would push our personal goals forward.
- Once a scroll started, it was so hard to stop and typically resulted in minutes to hours of time.
- Scrolling occurred at different times of day for us (key times were morning right when we wake up, or the night while trying to go to bed). 
- We had both done scrolling detoxes for a month, but got right back into scrolling after.
- We had used apps like BePresent that provided time-limits on apps, but we tended to bypass the time limits reguarly.

## Hypothesis
We believe that making screen time earnable, rather than simply restricting it, can help people build a healthier relationship with their phones. This draws a parallel to food dieting - restriction is rarely sustainable.

1. Make starting easier. By turning focus into an achievable, immediate reward, Bank lowers the barrier to starting work on personal goals.

2. Build momentum. Once users begin focusing, they're more likely to continue, make progress toward their goals, and choose how they spend their attention rather than defaulting to scrolling. 

## Product/Feature Thinking

When it comes to Focus Bank, the goal isn't to eliminate screen time or scroll time. It's to make it intentional and to use dopamine as a reward, in today's world where a dopamine-hit from scrolling is so easy to get.

Feature 1: Scroll/Screen Time should be earned not restricted
- Focus time = banked scroll time
- As a user, I should be able to Bank scroll/screen time for the time I spend with my Focus timer started. 
- As a user, if my Bank has any amount of time, my "restricted apps" should be openable and usable. If the Bank has no time, then the "restricted apps" should be unopenable/unusable.
- As a user, I should be able to choose the apps on my phone that I would like to restrict. I should be able to edit this at any time.

  * Note: Just because the focus timer is on, does not mean that the user is necessarily focusing. We see this as OK. At least they are taking a break from time-sink apps.
    
Feature 2: Scroll/Screen Time should require some activation energy, not be the first easy go-to.

- As a user, I should start my day (a day is midnight - 11:59pm) with negative 15 minutes of Banked Screen Time.

Other future features: Users can label their Focus Sprints to keep track of what they're working on, Data and stats of scroll time and focus time, Providing work for folks (math problems for kids, etc.) to earn screen time 

## How it works

**Balance** (top of screen) — shows available time in `MM:SS` monospace format. A "spending — apps unlocked" indicator appears while a spending session is active. Before completing 15 minutes of focus for the day, shows a countdown like `12:00 to first unlock`. When balance reaches zero, shows "Bank empty."

**Focus timer** (center) — a stopwatch. Press Start to begin a focus session — selected apps are shielded while focusing. Press Stop to end it. Whole earned minutes (`floor(elapsed / 60)`) are added to the balance as seconds. The elapsed time also counts toward the daily 15-minute unlock requirement.

**Opening a blocked app** — there is no button or interstitial. Whenever there's spendable balance, blocked apps are proactively unshielded — tapping one opens it immediately, same as any other app. Balance drains based on actual usage of the blocked apps (tracked by iOS's own Screen Time accounting, not wall-clock time), so it only counts down while you're actually in one of them — closing it pauses the drain. Once accumulated usage reaches the spendable amount, the app is shielded again automatically. If balance is already zero, blocked apps show the normal "Blocked" shield.

**Menu → Apps to Block** (bottom) — opens the system `FamilyActivityPicker` to choose which apps get shielded. Selection persists across launches.

**Show Log** (bottom) — opens a bottom sheet with a scrollable list of past sessions (date, duration, minutes earned), most recent first.

## Architecture

Native SwiftUI app with four extensions. No third-party dependencies.

### Targets

| Target | Purpose |
|--------|---------|
| `Bank` | Main app — UI, timer logic, shield management, proactively unshields/schedules spending sessions |
| `ShieldConfigurationExtension` | Customizes the block screen shown over shielded apps — always static copy, since a shield only ever appears once balance is already fully spent |
| `ShieldActionExtension` | Dismiss-only handler for the shield's button — there's nothing to grant, so it just closes the shield |
| `DeviceActivityMonitorExtension` | Re-shields and zeroes the balance once real usage of the blocked apps reaches the spendable amount |
| `BankWidgetExtension` | Live Activity showing the current focus/scrolling session on the Lock Screen and Dynamic Island |

### Frameworks

- **FamilyControls** — authorization to use Screen Time APIs, `FamilyActivityPicker` for app selection
- **ManagedSettings** — `ManagedSettingsStore` to apply/remove shields on selected apps
- **DeviceActivity** — `DeviceActivityEvent` usage-threshold monitoring is the core enforcement mechanism: it's the only channel a third-party app has into *actual* app usage (Apple restricts this for privacy), so it's what makes "drains only while the app is open" possible at all
- **ActivityKit** — Live Activities for the Lock Screen / Dynamic Island

### State

All state persists via `UserDefaults` with App Group `group.com.anushriadhia.bank` (shared between `Bank` and `DeviceActivityMonitorExtension`) — this is the only way they communicate, since they run in separate processes. `ShieldConfigurationExtension` and `ShieldActionExtension` don't need the App Group at all: they carry no logic, so they never read or write shared state.

| Key | Format | Purpose |
|-----|--------|---------|
| `balance` | Int (seconds) | Raw balance, rolls over indefinitely |
| `log` | `[Session]` JSON | History of completed focus sessions |
| `dailyFocus` | `{date, seconds}` JSON | Cumulative focus seconds for today's unlock gate |
| `selectedApps` | `FamilyActivitySelection` JSON | Which apps to shield |
| `scrolling` | Bool | Whether a spending session is currently active (apps unshielded, usage being monitored) |
| `scrollStartDate` | Double (`timeIntervalSince1970`) | When the active spending session started |
| `balanceAtScrollStart` | Int (seconds) | Raw balance at the moment the active session started |
| `spendableAtScrollStart` | Int (seconds) | How much of that balance was actually spendable (see `BankSpending` below) — this is the usage threshold the session monitors for, and what re-shielding floors against |

The daily focus tracker stores a date string (`YYYY-MM-DD`). On load, if the stored date doesn't match today, the daily counter resets to zero (midnight reset). Balance and log persist independently and never reset.

### Key logic

- **Unlock gate**: `dailyFocusSeconds >= 900` (15 minutes). Until met, nothing is spendable regardless of balance.
- **Earning**: On focus stop, `floor(elapsed / 60)` minutes are added to balance as seconds. Sessions under 60 seconds earn nothing but still count toward the daily unlock.
- **Spendable balance**: `Shared/BankSpending.swift` is the single definition of "how much can actually be spent right now" — `max(0, balance - 900)`, and only once `dailyFocusSeconds` meets today's unlock minimum (a day's worth of carried-over balance alone doesn't make it spendable). `AppStore` and `DeviceActivityMonitorExtension` both call into it rather than each computing their own version, which is what the unlock reserve actually is: balance you've earned but can't spend.
- **Proactive unshielding**: there's no button — `AppStore.syncShieldToSpendableBalance()` removes the shield the instant balance becomes spendable (checked on launch, on foreground, and right after a focus session ends, which are the only moments balance can change, since earning only ever happens in-app) and starts usage-threshold monitoring for the spendable amount. If spendable balance is ever zero and the shield isn't up, it reapplies it. The decision itself is the pure `ShieldSync.action(spendable:scrolling:focusRunning:)`, so it's unit-tested. A focus session always keeps apps shielded: starting one ends any running spending session (so `scrolling` never claims apps are unshielded while focus has blocked them), and stopping it re-syncs, starting a fresh session with the updated balance. Usage from the interrupted session isn't deducted, because DeviceActivity only reports usage via the threshold event, not as a running total.
- **Re-shielding is usage-based, not wall-clock**: a `DeviceActivityEvent` with `threshold: DateComponents(second: spendable)` monitors actual time spent in the selected apps/categories — this is the only channel that can see real app usage, which is what makes pausing-when-closed possible. `DeviceActivityMonitorExtension.eventDidReachThreshold` fires once accumulated usage reaches that threshold, re-applies the shield, and floors `balance` at the unlock reserve (`balanceAtScrollStart - spendableAtScrollStart`), landing bank display at exactly "00:00" rather than overshooting negative. `intervalDidEnd` is kept as a backstop re-shield in case the threshold event never fires, at the end of the monitoring window (midnight).
- **Monitoring window**: runs from now until 23:59:59 today. It ends at midnight because that's when the daily unlock resets, and because a window wrapping past midnight isn't reliably expressible with time-of-day components. Close to midnight the start moves earlier just enough to stay above `DeviceActivityCenter`'s 15-minute minimum (`MonitoringError.intervalTooShort`). On iOS 17.4+ the event is created with `includesPastActivity: false`, so only usage after the session starts counts toward the threshold. The real stop signal is the threshold event, not the window boundary.
- **Known reliability risk — accepted deliberately**: usage-threshold accounting is reported, across multiple developers and iOS versions, to sometimes fire early, late, or almost immediately regardless of actual usage. There is no alternative API that both reports real app-usage *and* fires with guaranteed precision — Apple doesn't expose that combination to third-party apps at all. This was chosen anyway because it's the only way to get "pauses when you close the app," which was prioritized over guaranteed-exact timing. Needs real on-device observation to know how this actually behaves on a given iOS version.
- **Live Activity**: `Activity.request()` can't be called from an extension (restricted context) — not an issue now, since sessions are only ever started by `AppStore` itself, which can call it directly. Neither focus nor scrolling has a knowable end time anymore (spending no longer drains on a fixed schedule), so both are simple count-ups from their start date — `startLiveActivity(kind:start:)` is the single entry point for both.

### File layout

```
Bank/
  BankApp.swift              — app entry point, authorization request
  AppStore.swift             — all state, persistence, timer, and shield logic
  ContentView.swift          — UI (balance, focus timer, log overlay)
  Bank.entitlements          — FamilyControls + App Group
  Info.plist

ShieldConfigurationExtension/
  ShieldConfigurationExtension.swift  — static block screen appearance
  Info.plist

ShieldActionExtension/
  ShieldActionExtension.swift  — dismiss-only shield button handler
  Info.plist

DeviceActivityMonitorExtension/
  DeviceActivityMonitorExtension.swift  — re-shields once usage reaches the spendable amount
  DeviceActivityMonitorExtension.entitlements
  Info.plist

BankWidgetExtension/
  BankWidgetsBundle.swift     — @main WidgetBundle entry point
  BankActivityWidget.swift    — Live Activity lock-screen + Dynamic Island views
  Info.plist

Shared/
  BankActivityAttributes.swift — ActivityAttributes/ContentState shared by Bank and BankWidgetExtension
  BankSpending.swift            — single definition of "how much is actually spendable right now"
  DeviceActivityNames.swift     — shared DeviceActivityName/DeviceActivityEvent.Name constants used by AppStore and DeviceActivityMonitorExtension
  BankLog.swift                 — unified-logging channel for monitoring events (view in Console.app, subsystem com.anushriadhia.bank)

project.yml                 — XcodeGen spec (generates Bank.xcodeproj)
```

## Setup

### Prerequisites

- Xcode 15+
- iOS 16.2+ device (Screen Time APIs don't work in Simulator)
- Apple Developer account with FamilyControls capability

### Build

```bash
# Generate the Xcode project (requires xcodegen: brew install xcodegen)
xcodegen generate

# Open in Xcode
open Bank.xcodeproj
```

In Xcode:
1. Signing uses the development team set in `project.yml` (`DEVELOPMENT_TEAM`) — change it there, not in Xcode, since `xcodegen generate` overwrites Xcode-side changes
2. Enable the "Family Controls" capability on the `Bank` and `DeviceActivityMonitorExtension` targets (the extension reapplies the shield and stops monitoring when a spending session ends) (requires applying to Apple for distribution; works in development without approval)
3. Add the "App Groups" capability with `group.com.anushriadhia.bank` to `Bank` and `DeviceActivityMonitorExtension` (`ShieldConfigurationExtension` and `ShieldActionExtension` carry no logic and don't read shared state at all; `BankWidgetExtension` doesn't need it either — Live Activity content is pushed to it directly by ActivityKit, not read from shared storage)
4. Build and run on a physical device

### Entitlement note

The `com.apple.developer.family-controls` entitlement requires [requesting access from Apple](https://developer.apple.com/contact/request/family-controls-distribution) for App Store distribution. During development, you can use it freely with your development provisioning profile — but this requires a paid Apple Developer Program enrollment; a free/personal-team Apple ID cannot use this entitlement at all, even locally, and `requestAuthorization()` will simply fail silently (the app runs, but every Screen Time–gated control stays hidden behind `authorized`).

## Design

Dark mode only. Black background, white monospace numbers, subtle borders. No icons, no labels beyond the essentials, no gamification. The shield screen matches — dark background with minimal text.

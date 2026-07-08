# Bank

A screen time budgeting app for iOS. You earn minutes by focusing, then spend them using blocked apps. When your balance runs out, apps get blocked again.

## Concept

Bank treats attention like currency. Focus sessions deposit minutes into your balance. Once you've hit the daily 15-minute focus minimum, you can "withdraw" by tapping Start Scrolling — this unblocks your selected apps and drains the balance in real time. When it hits zero, shields go back up.

## How it works

**Balance** (top of screen) — shows available time in `MM:SS` monospace format, draining per-second when scrolling is active. Before completing 15 minutes of focus for the day, shows a countdown like `12:00 to first unlock`. Once unlocked, a Start Scrolling / Stop Scrolling button appears. When balance reaches zero, shows "Bank empty."

**Focus timer** (center) — a stopwatch. Press Start to begin a focus session — selected apps are shielded while focusing. Press Stop to end it. Whole earned minutes (`floor(elapsed / 60)`) are added to the balance as seconds. The elapsed time also counts toward the daily 15-minute unlock requirement.

**Select Apps to Block** (bottom) — opens the system `FamilyActivityPicker` to choose which apps get shielded. Selection persists across launches.

**Show Log** (bottom) — opens a bottom sheet with a scrollable list of past sessions (date, duration, minutes earned), most recent first.

## Architecture

Native SwiftUI app with three extensions. No third-party dependencies.

### Targets

| Target | Purpose |
|--------|---------|
| `Bank` | Main app — UI, timer logic, shield management |
| `ShieldConfigurationExtension` | Customizes the block screen shown over shielded apps |
| `DeviceActivityMonitorExtension` | Handles scheduled device activity events |
| `BankWidgetExtension` | Live Activity showing the current focus/scrolling timer on the Lock Screen and Dynamic Island |

### Frameworks

- **FamilyControls** — authorization to use Screen Time APIs, `FamilyActivityPicker` for app selection
- **ManagedSettings** — `ManagedSettingsStore` to apply/remove shields on selected apps
- **DeviceActivity** — extension point for monitoring device activity schedules
- **ActivityKit** — Live Activities for the Lock Screen / Dynamic Island

### State

All state persists via `UserDefaults` with App Group `group.com.bank.app` (shared between main app and extensions).

| Key | Format | Purpose |
|-----|--------|---------|
| `balance` | Int (seconds) | Spendable balance, rolls over indefinitely |
| `log` | `[Session]` JSON | History of completed focus sessions |
| `dailyFocus` | `{date, seconds}` JSON | Cumulative focus seconds for today's unlock gate |
| `selectedApps` | `FamilyActivitySelection` JSON | Which apps to shield |

The daily focus tracker stores a date string (`YYYY-MM-DD`). On load, if the stored date doesn't match today, the daily counter resets to zero (midnight reset). Balance and log persist independently and never reset.

### Key logic

- **Unlock gate**: `dailyFocusSeconds >= 900` (15 minutes). Until met, the balance section shows time remaining to unlock instead of the spend button.
- **Earning**: On focus stop, `floor(elapsed / 60)` minutes are added to balance as seconds. Sessions under 60 seconds earn nothing but still count toward the daily unlock.
- **Spending**: "Start Scrolling" removes shields and starts a 1-second interval that decrements balance. Auto-stops and re-shields at zero.
- **Shielding**: Focus start and scrolling stop both call `applyShield()`. Scrolling start calls `removeShield()`. The shield screen says "Blocked — Open Bank to earn more time."
- **Live Activity**: starting/stopping a focus or scrolling session starts/ends an ActivityKit Live Activity mirroring that session's timer. Focus shows a count-up from `focusStartDate`; scrolling shows a deterministic count-down from `balanceAtScrollStart` seconds, ending at a fixed date computed once at session start — the widget's `Text(date:style:.timer)` / `Text(timerInterval:countsDown:)` views update themselves live without further app involvement.

### File layout

```
Bank/
  BankApp.swift              — app entry point, authorization request
  AppStore.swift             — all state, persistence, timer, and shield logic
  ContentView.swift          — UI (balance, focus timer, log overlay)
  Bank.entitlements          — FamilyControls + App Group
  Info.plist

ShieldConfigurationExtension/
  ShieldConfigurationExtension.swift  — custom block screen appearance
  ShieldConfigurationExtension.entitlements
  Info.plist

DeviceActivityMonitorExtension/
  DeviceActivityMonitorExtension.swift  — activity schedule callbacks
  DeviceActivityMonitorExtension.entitlements
  Info.plist

BankWidgetExtension/
  BankWidgetsBundle.swift     — @main WidgetBundle entry point
  BankActivityWidget.swift    — Live Activity lock-screen + Dynamic Island views
  Info.plist

Shared/
  BankActivityAttributes.swift — ActivityAttributes/ContentState shared by Bank and BankWidgetExtension

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
1. Set your development team under Signing & Capabilities for all four targets
2. Enable the "Family Controls" capability on the Bank target (requires applying to Apple for distribution; works in development without approval)
3. Add the "App Groups" capability with `group.com.bank.app` to `Bank`, `ShieldConfigurationExtension`, and `DeviceActivityMonitorExtension` (`BankWidgetExtension` doesn't need it — Live Activity content is pushed to it directly by ActivityKit, not read from shared storage)
4. Build and run on a physical device

### Entitlement note

The `com.apple.developer.family-controls` entitlement requires [requesting access from Apple](https://developer.apple.com/contact/request/family-controls-distribution) for App Store distribution. During development, you can use it freely with your development provisioning profile.

## Design

Dark mode only. Black background, white monospace numbers, subtle borders. No icons, no labels beyond the essentials, no gamification. The shield screen matches — dark background with minimal text.

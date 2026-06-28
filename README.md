# Bank

A screen time budgeting app. You earn minutes by focusing, then spend them scrolling.

## Concept

Bank treats attention like currency. Focus sessions deposit minutes into your balance. Once you've hit the daily 15-minute focus minimum, you can "withdraw" by scrolling — the balance drains in real time until it hits zero.

## How it works

**Balance** (top of screen) — shows your available minutes in `MM:SS` format. Before completing 15 minutes of focus for the day, it shows a countdown like `12:00 to first unlock` instead of the spend button. Once unlocked, a Start Scrolling / Stop Scrolling button appears. When balance reaches zero, it shows "Bank empty."

**Focus timer** (center) — a stopwatch. Press Start to begin a focus session. Press Stop to end it. On stop, whole earned minutes (`floor(elapsed / 60)`) are added to the balance. The elapsed seconds also count toward the daily 15-minute unlock requirement.

**Show Log** (bottom) — opens a bottom sheet with a scrollable list of past sessions (date, duration, minutes earned), most recent first.

## Architecture

Single-screen React Native Expo app. Everything lives in `App.tsx` — no navigation, no external state management.

### State

| Key | Storage | Format | Purpose |
|-----|---------|--------|---------|
| `@bank_balance` | AsyncStorage | integer (minutes) | Spendable balance, rolls over indefinitely |
| `@bank_log` | AsyncStorage | `Session[]` JSON | History of completed focus sessions |
| `@bank_daily_focus` | AsyncStorage | `{date, seconds}` JSON | Tracks cumulative focus seconds for today's unlock gate |

The daily focus tracker stores a date string (`YYYY-MM-DD`). On load, if the stored date doesn't match today, the daily counter resets to zero (midnight reset). Balance and log persist independently and never reset.

### Key logic

- **Unlock gate**: `dailyFocusSeconds >= 900` (15 minutes). Until met, the balance section shows time remaining to unlock instead of the spend button.
- **Earning**: On focus stop, `floor(elapsed / 60)` minutes are added to balance. Sessions under 60 seconds earn nothing but still count toward the daily unlock.
- **Spending**: "Start Scrolling" starts a 1-second interval that decrements balance by 1 each tick. Stops automatically at zero.
- **Persistence**: All three storage keys are written together via `persist()` after any state change. Balance is also written inline during scrolling drain for crash safety.

### Dependencies

- `expo` (SDK 56) — runtime and dev tooling
- `@react-native-async-storage/async-storage` — persistence
- `expo-status-bar` — light status bar on dark background

No navigation library, no animation library, no state management library.

## Running

```
npm install
npx expo start
```

Press `w` for web, `i` for iOS simulator, `a` for Android emulator.

## Design

Dark mode only. Black background (`#000`), white monospace numbers, `#333` button borders, `#666` sublabels. No icons, no labels, no gamification. The log modal has a `#111` background with `#888` text.

@AGENTS.md

This is a native iOS SwiftUI app that uses Apple's Screen Time APIs (FamilyControls, ManagedSettings, DeviceActivity) to block and unblock apps.

The project uses XcodeGen — run `xcodegen generate` to regenerate `Bank.xcodeproj` from `project.yml` after adding files or changing targets.

Screen Time APIs require a physical iOS device. The Simulator does not support FamilyControls authorization or ManagedSettingsStore shielding.

All app state lives in `AppStore.swift`. The UI is in `ContentView.swift`. There are no third-party dependencies.

## Engineering standards

You are a senior iOS engineer. Apply these principles to every change:

- **Clarity over cleverness.** Code should read like plain English. Future readers matter more than saving lines.
- **Small, focused changes.** Don't refactor or clean up code unrelated to the task at hand. One concern per PR.
- **No dead code.** Remove unused variables, functions, and imports rather than commenting them out.
- **Prefer value types.** Use structs and enums where possible. Classes only when reference semantics are needed.
- **Explicit over implicit.** Name things for what they are. Avoid abbreviations. Avoid magic numbers — give constants names.
- **No unnecessary abstraction.** Don't introduce protocols, generics, or layers of indirection until there's a clear, concrete reason.
- **State lives in one place.** `AppStore` owns all state. Views are dumb — they read from the store and call methods on it, nothing more.
- **Design before implementing.** When adding a feature, think about where it belongs in the architecture before writing code. Ask: does this belong in the store, the view, or a new type? Don't reach for the quickest path if a cleaner one exists.
- **Respect the existing architecture.** This app has a clear separation — `AppStore` for logic and state, views for display only. New features should fit that shape, not work around it.
- **Prefer composable, testable units.** Logic that can be extracted into a pure function or a small dedicated type should be. Avoid putting business logic directly in view lifecycle methods or timers.
- **Ask before committing or pushing.** Always confirm with the user before running `git commit` or `git push`.
- **Keep the README current.** When behavior or architecture changes, update `README.md` to reflect it.
- **Maintain tests.** `BankTests/` covers happy-path logic in `AppStore`. When adding or changing behavior, update the tests to match. Don't leave tests broken or stale.

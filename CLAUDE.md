@AGENTS.md

This is a native iOS SwiftUI app that uses Apple's Screen Time APIs (FamilyControls, ManagedSettings, DeviceActivity) to block and unblock apps.

The project uses XcodeGen — run `xcodegen generate` to regenerate `Bank.xcodeproj` from `project.yml` after adding files or changing targets.

Screen Time APIs require a physical iOS device. The Simulator does not support FamilyControls authorization or ManagedSettingsStore shielding.

All app state lives in `AppStore.swift`. The UI is in `ContentView.swift`. There are no third-party dependencies.

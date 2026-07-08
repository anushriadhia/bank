# Screen Time API

Read Apple's official docs before modifying shield or authorization code:
- FamilyControls: https://developer.apple.com/documentation/familycontrols
- ManagedSettings: https://developer.apple.com/documentation/managedsettings
- DeviceActivity: https://developer.apple.com/documentation/deviceactivity

These APIs change between iOS versions. Check the deployment target (iOS 16.2) before using newer APIs. (Bumped from 16.0 to 16.2 to use ActivityKit's Live Activities, which require 16.1+, and the non-deprecated request/end API specifically requires 16.2+.)

# XcodeGen

The Xcode project is generated from `project.yml`. Do not edit `Bank.xcodeproj` directly — it will be overwritten. Add new source files to the correct target directory and regenerate with `xcodegen generate`.

# Testing

Screen Time APIs only work on physical devices. Do not attempt to test shielding behavior in the Simulator. Live Activities are different: they can be previewed in Xcode's canvas (`#Preview` with a Live Activity preview context) and exercised on the Simulator's Lock Screen (Hardware → Lock), since ActivityKit — unlike FamilyControls/ManagedSettings — does work in Simulator. Dynamic Island presentations still need a physical iPhone 14 Pro or later.

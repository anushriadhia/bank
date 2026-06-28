# Screen Time API

Read Apple's official docs before modifying shield or authorization code:
- FamilyControls: https://developer.apple.com/documentation/familycontrols
- ManagedSettings: https://developer.apple.com/documentation/managedsettings
- DeviceActivity: https://developer.apple.com/documentation/deviceactivity

These APIs change between iOS versions. Check the deployment target (iOS 16.0) before using newer APIs.

# XcodeGen

The Xcode project is generated from `project.yml`. Do not edit `Bank.xcodeproj` directly — it will be overwritten. Add new source files to the correct target directory and regenerate with `xcodegen generate`.

# Testing

Screen Time APIs only work on physical devices. Do not attempt to test shielding behavior in the Simulator.

# Changelog

## [0.1.2] - 2026-10-29

### Added
- Android: `callIdKey` names the push field that holds the call ID (default `callId`; `callId` and `uuid` are tried after it). Uses Android VoIP SDK 0.1.1, which also no longer writes call payloads and caller names to the device log.

## [0.1.1] - 2026-10-12

### Added
- iOS: the VoIP token registration reports the package's identity (`sdkName: react-native-voip`, `sdkVersion`) so the dashboard can tell these registrations apart.

## [0.1.0] - 2026-04-24

### Added
- Native incoming call UI for iOS (CallKit) and Android (CallStyle notifications)
- PushKit VoIP push registration and handling (iOS)
- Self-contained plugin — no AppDelegate VoIP code required
- Cold start support with config persistence (UserDefaults/SharedPreferences)
- Device ID resolution matching RiviumPush SDK
- VoIP token management and server registration (iOS)
- `setApiKey()` for VoIP token registration with server
- `isConfigured()` to check persisted VoIP state across app restarts
- Dart API: init, setApiKey, showIncomingCall, endCall, getInitialCall, isConfigured

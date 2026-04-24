# RiviumPush VoIP

VoIP call handling add-on for [rivium-push-react-native](https://www.npmjs.com/package/rivium-push-react-native) push notifications.

This plugin intercepts VoIP call push notifications and shows native incoming call UI:
- **Android**: CallStyle notification (Android 12+) with full-screen incoming call activity
- **iOS**: CallKit with native iOS call screen

## Features

- Native incoming call UI on both platforms
- Works when app is in foreground, background, or terminated
- Self-contained: no AppDelegate changes needed on iOS
- Configurable timeout and missed call notifications
- Supports audio and video calls
- Cold start support: app launched from call notification

## Installation

```bash
npm install rivium-push-react-native-voip
# or
yarn add rivium-push-react-native-voip
```

### iOS

```bash
cd ios && pod install
```

### Android

No additional setup required — autolinking handles it.

## Usage

### 1. Initialize the plugin

```typescript
import RiviumPush from 'rivium-push-react-native';
import RiviumPushVoip from 'rivium-push-react-native-voip';

// Initialize RiviumPush first
await RiviumPush.init({
  apiKey: 'rv_live_your_api_key',
});

await RiviumPush.register();

// Initialize VoIP
await RiviumPushVoip.init({
  appName: 'MyApp',
  callTimeout: 30,
});

// Set API key for VoIP token registration (iOS PushKit)
const deviceId = await RiviumPush.getDeviceId();
await RiviumPushVoip.setApiKey({
  apiKey: 'rv_live_your_api_key',
  deviceId: deviceId,
});

// Listen for call events
RiviumPushVoip.onCallAccepted((callData) => {
  navigateToCallScreen(callData);
});

RiviumPushVoip.onCallDeclined((callData) => {
  notifyCallDeclined(callData.callId);
});

RiviumPushVoip.onCallTimeout((callData) => {
  handleMissedCall(callData);
});

// Check for initial call (app launched from call notification)
const initialCall = await RiviumPushVoip.getInitialCall();
if (initialCall) {
  navigateToCallScreen(initialCall);
}
```

### 2. Send VoIP call from server

Send a push message with `type: "voip_call"` in the data:

```json
{
  "title": "Incoming Call",
  "body": "John Doe is calling",
  "data": {
    "type": "voip_call",
    "callerName": "John Doe",
    "callerId": "user123",
    "callerAvatar": "https://example.com/avatar.jpg",
    "callType": "video"
  }
}
```

The `type: "voip_call"` field triggers VoIP delivery. Without it, the message is delivered as a regular push notification.

### 3. End the call

```typescript
await RiviumPushVoip.endCall(callData.callId);
```

### 4. Report call connected (iOS)

On iOS, report when the actual call connection is established:

```typescript
await RiviumPushVoip.reportCallConnected(callData.callId);
```

## Configuration

```typescript
await RiviumPushVoip.init({
  appName: 'MyApp',                    // App name shown in call UI
  ringtoneUri: 'ringtone.mp3',         // Custom ringtone (optional)
  callTimeout: 30,                     // Call timeout in seconds (default: 30)
  callerNameKey: 'callerName',         // Payload key for caller name
  callerIdKey: 'callerId',             // Payload key for caller ID
  callerAvatarKey: 'callerAvatar',     // Payload key for avatar URL
  callTypeKey: 'callType',             // Payload key for call type
});
```

## Platform Setup

### Android

Add permissions to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.VIBRATE" />
```

### iOS

Enable in Xcode -> Signing & Capabilities:
- **Push Notifications**
- **Background Modes** -> Voice over IP, Remote notifications

No AppDelegate changes needed. The plugin handles PushKit registration, VoIP token management, and CallKit internally.

## API Reference

### RiviumPushVoip

| Method | Description |
|--------|-------------|
| `init(config)` | Initialize the VoIP plugin with config |
| `setApiKey(params)` | Set API key for VoIP token registration with server |
| `getInitialCall()` | Get the call that launched the app (cold start) |
| `endCall(callId)` | End/dismiss a call |
| `reportCallConnected(callId)` | Report call as connected (iOS) |
| `showIncomingCall(callData)` | Manually trigger incoming call UI |
| `isConfigured()` | Check if VoIP was previously enabled (async) |
| `isInitialized()` | Check if plugin is currently initialized |

### Event Listeners

| Method | Description |
|--------|-------------|
| `onCallAccepted(callback)` | User accepted the incoming call |
| `onCallDeclined(callback)` | User declined the incoming call |
| `onCallTimeout(callback)` | Call timed out (not answered) |
| `onError(callback)` | An error occurred |
| `removeAllListeners()` | Remove all event listeners |

### CallData

| Property | Type | Description |
|----------|------|-------------|
| `callId` | string | Unique call identifier |
| `callerName` | string | Name of the caller |
| `callerId` | string? | Optional caller ID |
| `callerAvatar` | string? | Optional avatar URL |
| `callType` | 'audio' \| 'video' | Call type |
| `payload` | object? | Additional payload data |
| `timestamp` | number | When call was received |

## How It Works

1. When VoIP is initialized, the plugin registers for PushKit (iOS) and saves the VoIP token to the server
2. When a push with `data.type = "voip_call"` is sent, the server delivers it via VoIP push (PushKit on iOS, high-priority on Android)
3. The plugin receives the push natively and shows CallKit (iOS) or CallStyle notification (Android)
4. Works in all app states: foreground, background, and terminated
5. On cold start (app killed), iOS relaunches the app and the plugin auto-initializes from saved config

## Links

- [Rivium Push](https://rivium.co/cloud/rivium-push) - Learn more about Rivium Push
- [Documentation](https://rivium.co/cloud/rivium-push/docs/quick-start) - Full documentation and guides
- [Rivium Console](https://console.rivium.co) - Manage your push notifications

## License

MIT License - see [LICENSE](LICENSE) for details.

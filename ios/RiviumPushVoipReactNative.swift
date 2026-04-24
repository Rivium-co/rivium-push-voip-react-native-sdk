/**
 * RiviumPush VoIP React Native iOS Module — Self-Contained
 *
 * Handles PushKit + CallKit independently from the main Push SDK.
 * Works when app is killed: PushKit wakes app → CallKit shows → user accepts → RN starts
 *
 * Architecture:
 * - Registers for PushKit VoIP pushes directly (no dependency on main Push SDK for VoIP)
 * - Shows CallKit natively when VoIP push arrives
 * - Sends VoIP token to Rivium server using the API key
 * - When RN is running: forwards events via event emitter
 * - When app is killed: stores accepted call → RN reads via getInitialCall()
 */
import Foundation
import PushKit
import React
import RiviumPushVoip

@objc(RiviumPushVoipReactNative)
class RiviumPushVoipReactNative: RCTEventEmitter {

    private var hasListeners = false
    private static var instance: RiviumPushVoipReactNative?
    private static var pendingEvents: [(String, Any?)] = []
    private static let pendingEventsLock = NSLock()

    // PushKit registry (static to survive lifecycle)
    private static var voipRegistry: PKPushRegistry?

    // Config persistence keys
    private static let configKey = "rivium_push_voip_config"
    private static let apiKeyKey = "rivium_push_voip_api_key"
    private static let deviceIdKey = "rivium_push_voip_device_id"
    private static let serverUrlKey = "rivium_push_voip_server_url"

    // Push SDK device ID key (to match token with correct device record)
    private static let pushSdkDeviceIdKey = "co.rivium.push.deviceId"

    // Server URL
    private static let defaultServerUrl = "https://push-api.rivium.co"

    override init() {
        super.init()
        RiviumPushVoipReactNative.instance = self

        // Set up delegate to receive callbacks from native SDK
        RiviumPushVoip.shared.delegate = self

        // Auto-initialize VoIP SDK if previously configured (for cold start)
        if let savedConfig = UserDefaults.standard.dictionary(forKey: RiviumPushVoipReactNative.configKey) {
            autoInitialize(savedConfig: savedConfig)
        }

        // Deliver any pending events
        deliverPendingEvents()

        print("[RiviumPushVoipRN] Plugin initialized")
    }

    override static func moduleName() -> String! {
        return "RiviumPushVoipReactNative"
    }

    override static func requiresMainQueueSetup() -> Bool {
        return true
    }

    override func supportedEvents() -> [String]! {
        return [
            "onCallAccepted",
            "onCallDeclined",
            "onCallTimeout",
            "onError"
        ]
    }

    override func startObserving() {
        hasListeners = true
        deliverPendingEvents()
    }

    override func stopObserving() {
        hasListeners = false
    }

    // MARK: - Auto-Initialize (Cold Start)

    private func autoInitialize(savedConfig: [String: Any]) {
        let appName = savedConfig["appName"] as? String ?? "App"
        guard !appName.isEmpty else { return }

        let config = VoipConfig(
            appName: appName,
            callTimeout: savedConfig["callTimeout"] as? Int ?? savedConfig["timeoutSeconds"] as? Int ?? 30,
            supportsVideo: savedConfig["supportsVideo"] as? Bool ?? true
        )

        RiviumPushVoip.shared.initialize(config: config)
        RiviumPushVoip.shared.delegate = self
        registerPushKit()

        print("[RiviumPushVoipRN] Auto-initialized for cold start: \(appName)")
    }

    // MARK: - PushKit Registration

    private func registerPushKit() {
        if RiviumPushVoipReactNative.voipRegistry == nil {
            RiviumPushVoipReactNative.voipRegistry = PKPushRegistry(queue: .main)
            RiviumPushVoipReactNative.voipRegistry?.delegate = self
            RiviumPushVoipReactNative.voipRegistry?.desiredPushTypes = [.voIP]
            print("[RiviumPushVoipRN] PushKit registered for VoIP")
        }
    }

    // MARK: - Device ID Resolution

    /// Resolve the device ID: check VoIP-specific key, then Push SDK key, then system fallback
    private func resolveDeviceId() -> String {
        if let id = UserDefaults.standard.string(forKey: RiviumPushVoipReactNative.deviceIdKey), !id.isEmpty {
            return id
        }
        if let id = UserDefaults.standard.string(forKey: RiviumPushVoipReactNative.pushSdkDeviceIdKey), !id.isEmpty {
            return id
        }
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    // MARK: - VoIP Token Server Registration

    private func sendVoipTokenToServer(_ token: String) {
        guard let apiKey = UserDefaults.standard.string(forKey: RiviumPushVoipReactNative.apiKeyKey), !apiKey.isEmpty else {
            print("[RiviumPushVoipRN] No API key saved, skipping token registration")
            return
        }

        let deviceId = resolveDeviceId()
        let serverUrl = UserDefaults.standard.string(forKey: RiviumPushVoipReactNative.serverUrlKey) ?? RiviumPushVoipReactNative.defaultServerUrl
        let appIdentifier = Bundle.main.bundleIdentifier ?? "unknown"

        guard let url = URL(string: "\(serverUrl)/devices/register") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "deviceId": deviceId,
            "platform": "ios",
            "pushToken": token,
            "appIdentifier": appIdentifier,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                print("[RiviumPushVoipRN] VoIP token sent: \(http.statusCode)")
            }
        }.resume()
    }

    // MARK: - Methods

    @objc(init:resolver:rejecter:)
    func initialize(config: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        let voipConfig = VoipConfig(
            appName: config["appName"] as? String ?? "App",
            vibrate: config["vibrate"] as? Bool ?? true,
            callTimeout: config["callTimeout"] as? Int ?? 30,
            supportsVideo: config["supportsVideo"] as? Bool ?? false,
            ringtoneName: config["ringtoneUri"] as? String,
            callIdKey: config["callIdKey"] as? String ?? "call_id",
            callerNameKey: config["callerNameKey"] as? String ?? "callerName",
            callerIdKey: config["callerIdKey"] as? String ?? "callerId",
            callerAvatarKey: config["callerAvatarKey"] as? String ?? "callerAvatar",
            callTypeKey: config["callTypeKey"] as? String ?? "callType"
        )

        RiviumPushVoip.shared.initialize(config: voipConfig)
        RiviumPushVoip.shared.delegate = self

        // Save config for cold start auto-initialization
        let configDict = config as? [String: Any] ?? [:]
        let safeConfig = configDict.compactMapValues { $0 is NSNull ? nil : $0 }
        UserDefaults.standard.set(safeConfig, forKey: RiviumPushVoipReactNative.configKey)

        // Register PushKit for VoIP pushes
        registerPushKit()

        // Check for pending initial call
        if let call = RiviumPushVoip.shared.getInitialCall() {
            emitEvent("onCallAccepted", body: callDataToDictionary(call))
        }

        print("[RiviumPushVoipRN] Initialized with config: \(voipConfig.appName)")
        resolve(nil)
    }

    @objc(isConfigured:rejecter:)
    func isConfigured(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        let hasConfig = UserDefaults.standard.dictionary(forKey: RiviumPushVoipReactNative.configKey) != nil
        resolve(hasConfig)
    }

    @objc(setApiKey:resolver:rejecter:)
    func setApiKey(config: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        let apiKey = config["apiKey"] as? String ?? ""
        let deviceId = config["deviceId"] as? String ?? ""
        let serverUrl = config["serverUrl"] as? String ?? RiviumPushVoipReactNative.defaultServerUrl

        guard !apiKey.isEmpty else {
            reject("INVALID_ARGUMENT", "apiKey is required", nil)
            return
        }

        UserDefaults.standard.set(apiKey, forKey: RiviumPushVoipReactNative.apiKeyKey)
        if !deviceId.isEmpty {
            UserDefaults.standard.set(deviceId, forKey: RiviumPushVoipReactNative.deviceIdKey)
        }
        UserDefaults.standard.set(serverUrl, forKey: RiviumPushVoipReactNative.serverUrlKey)
        print("[RiviumPushVoipRN] API key saved for VoIP token registration")

        // Re-send VoIP token now that we have the API key + device ID
        if let token = RiviumPushVoipReactNative.voipRegistry?.pushToken(for: .voIP) {
            let tokenStr = token.map { String(format: "%02x", $0) }.joined()
            sendVoipTokenToServer(tokenStr)
        }

        resolve(nil)
    }

    @objc(getInitialCall:rejecter:)
    func getInitialCall(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        if let call = RiviumPushVoip.shared.getInitialCall() {
            RiviumPushVoip.shared.clearInitialCall()
            resolve(callDataToDictionary(call))
        } else {
            resolve(nil)
        }
    }

    @objc(endCall:resolver:rejecter:)
    func endCall(callId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        RiviumPushVoip.shared.endCall(callId: callId)
        resolve(nil)
    }

    @objc(reportCallConnected:resolver:rejecter:)
    func reportCallConnected(callId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        RiviumPushVoip.shared.reportCallConnected(callId: callId)
        resolve(nil)
    }

    @objc(showIncomingCall:resolver:rejecter:)
    func showIncomingCall(callData: NSDictionary, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        let call = dictionaryToCallData(callData)
        RiviumPushVoip.shared.showIncomingCall(callData: call)
        resolve(nil)
    }

    // MARK: - Event Emission

    private func emitEvent(_ name: String, body: Any?) {
        if hasListeners {
            sendEvent(withName: name, body: body)
        } else {
            RiviumPushVoipReactNative.pendingEventsLock.lock()
            RiviumPushVoipReactNative.pendingEvents.append((name, body))
            RiviumPushVoipReactNative.pendingEventsLock.unlock()
        }
    }

    private func deliverPendingEvents() {
        RiviumPushVoipReactNative.pendingEventsLock.lock()
        defer { RiviumPushVoipReactNative.pendingEventsLock.unlock() }

        guard !RiviumPushVoipReactNative.pendingEvents.isEmpty, hasListeners else { return }

        let events = RiviumPushVoipReactNative.pendingEvents
        RiviumPushVoipReactNative.pendingEvents.removeAll()

        for (name, body) in events {
            sendEvent(withName: name, body: body)
        }
    }

    // MARK: - Helpers

    private func callDataToDictionary(_ callData: VoipCallData) -> [String: Any] {
        var dict: [String: Any] = [
            "callId": callData.callId,
            "callerName": callData.callerName,
            "callType": callData.callType,
            "timestamp": callData.timestamp
        ]
        if let callerId = callData.callerId {
            dict["callerId"] = callerId
        }
        if let callerAvatar = callData.callerAvatar {
            dict["callerAvatar"] = callerAvatar
        }
        if let payload = callData.payload {
            dict["payload"] = payload
        }
        return dict
    }

    private func dictionaryToCallData(_ dict: NSDictionary) -> VoipCallData {
        return VoipCallData(
            callId: dict["callId"] as? String ?? "",
            callerName: dict["callerName"] as? String ?? "Unknown",
            callerId: dict["callerId"] as? String,
            callerAvatar: dict["callerAvatar"] as? String,
            callType: dict["callType"] as? String ?? "audio",
            payload: dict["payload"] as? [String: Any],
            timestamp: dict["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970 * 1000
        )
    }
}

// MARK: - PKPushRegistryDelegate
extension RiviumPushVoipReactNative: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("[RiviumPushVoipRN] VoIP token: \(String(token.prefix(20)))...")
        sendVoipTokenToServer(token)
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }

        print("[RiviumPushVoipRN] VoIP push received!")

        // Let VoIP SDK handle it (shows CallKit synchronously)
        let handled = RiviumPushVoip.shared.handlePushPayload(payload.dictionaryPayload)

        if !handled {
            // Fallback: must report a call to CallKit (Apple requirement since iOS 13)
            let data = payload.dictionaryPayload
            let nestedData = data["data"] as? [String: Any] ?? [:]
            let effectiveData = nestedData.isEmpty ? data as? [String: Any] ?? [:] : nestedData

            let callData = VoipCallData(
                callId: effectiveData["callId"] as? String ?? UUID().uuidString,
                callerName: effectiveData["callerName"] as? String ?? "Unknown",
                callerId: effectiveData["callerId"] as? String,
                callerAvatar: effectiveData["callerAvatar"] as? String,
                callType: effectiveData["callType"] as? String ?? "audio"
            )
            RiviumPushVoip.shared.showIncomingCall(callData: callData)
        }

        completion()
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("[RiviumPushVoipRN] VoIP token invalidated")
    }
}

// MARK: - RiviumPushVoipDelegate
extension RiviumPushVoipReactNative: RiviumPushVoipDelegate {
    func voip(_ voip: RiviumPushVoip, didAcceptCall callData: VoipCallData) {
        print("[RiviumPushVoipRN] Call accepted: \(callData.callId)")
        emitEvent("onCallAccepted", body: callDataToDictionary(callData))
    }

    func voip(_ voip: RiviumPushVoip, didDeclineCall callData: VoipCallData) {
        print("[RiviumPushVoipRN] Call declined: \(callData.callId)")
        emitEvent("onCallDeclined", body: callDataToDictionary(callData))
    }

    func voip(_ voip: RiviumPushVoip, didTimeoutCall callData: VoipCallData) {
        print("[RiviumPushVoipRN] Call timeout: \(callData.callId)")
        emitEvent("onCallTimeout", body: callDataToDictionary(callData))
    }

    func voip(_ voip: RiviumPushVoip, didFailWithError error: String) {
        print("[RiviumPushVoipRN] Error: \(error)")
        emitEvent("onError", body: error)
    }
}

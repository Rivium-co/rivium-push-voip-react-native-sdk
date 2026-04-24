/**
 * RiviumPush VoIP React Native Module
 * Thin wrapper around the native RiviumPush VoIP SDK
 */
package co.rivium.push.voip.reactnative

import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule

// Import from native VoIP SDK
import co.rivium.push.voip.CallData
import co.rivium.push.voip.RiviumPushVoip
import co.rivium.push.voip.VoipCallback
import co.rivium.push.voip.VoipConfig

class RiviumPushVoipReactNativeModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    companion object {
        const val TAG = "RiviumPushVoipRN"
        const val NAME = "RiviumPushVoipReactNative"
    }

    private var listenerCount = 0

    private var sdkInitialized = false

    init {
        try {
            // Initialize native SDK with defaults
            RiviumPushVoip.initialize(reactContext, VoipConfig())
            setupCallbacks()
            sdkInitialized = true
            Log.d(TAG, "RiviumPush VoIP React Native module initialized")
        } catch (e: Exception) {
            Log.e(TAG, "VoIP SDK init deferred: ${e.message}")
        }
    }

    private fun setupCallbacks() {
        RiviumPushVoip.setCallback(object : VoipCallback {
            override fun onCallAccepted(callData: CallData) {
                Log.d(TAG, "Call accepted: ${callData.callId}")
                sendEvent("onCallAccepted", callDataToMap(callData))
            }

            override fun onCallDeclined(callData: CallData) {
                Log.d(TAG, "Call declined: ${callData.callId}")
                sendEvent("onCallDeclined", callDataToMap(callData))
            }

            override fun onCallTimeout(callData: CallData) {
                Log.d(TAG, "Call timeout: ${callData.callId}")
                sendEvent("onCallTimeout", callDataToMap(callData))
            }

            override fun onError(error: String) {
                Log.e(TAG, "Error: $error")
                sendEvent("onError", error)
            }
        })
    }

    override fun getName(): String = NAME

    @ReactMethod
    fun isConfigured(promise: Promise) {
        val prefs = reactApplicationContext.getSharedPreferences("rivium_push_voip", 0)
        promise.resolve(prefs.getBoolean("configured", false))
    }

    @ReactMethod
    fun init(configMap: ReadableMap, promise: Promise) {
        try {
            val config = VoipConfig(
                appName = configMap.getString("appName") ?: "App",
                ringtoneUri = configMap.getString("ringtoneUri"),
                timeoutSeconds = if (configMap.hasKey("callTimeout")) configMap.getInt("callTimeout") else 30,
                callerNameKey = configMap.getString("callerNameKey") ?: "callerName",
                callerIdKey = configMap.getString("callerIdKey") ?: "callerId",
                callerAvatarKey = configMap.getString("callerAvatarKey") ?: "callerAvatar",
                callTypeKey = configMap.getString("callTypeKey") ?: "callType"
            )

            if (!sdkInitialized) {
                RiviumPushVoip.initialize(reactApplicationContext, config)
                setupCallbacks()
                sdkInitialized = true
            } else {
                RiviumPushVoip.updateConfig(config)
            }
            // Persist configured state
            reactApplicationContext.getSharedPreferences("rivium_push_voip", 0)
                .edit().putBoolean("configured", true).apply()

            Log.d(TAG, "VoIP initialized with config")

            // Check for pending initial call
            RiviumPushVoip.getInitialCall()?.let { call ->
                Log.d(TAG, "Delivering pending initial call: ${call.callId}")
                sendEvent("onCallAccepted", callDataToMap(call))
            }

            promise.resolve(null)
        } catch (e: Exception) {
            Log.e(TAG, "Init error: ${e.message}")
            promise.reject("INIT_ERROR", e.message)
        }
    }

    @ReactMethod
    fun setApiKey(config: ReadableMap, promise: Promise) {
        // No-op on Android — PushKit/VoIP tokens are iOS only
        // Android uses regular FCM/MQTT for all push delivery
        Log.d(TAG, "setApiKey: no-op on Android")
        promise.resolve(null)
    }

    @ReactMethod
    fun getInitialCall(promise: Promise) {
        try {
            val call = RiviumPushVoip.getInitialCall()
            if (call != null) {
                promise.resolve(callDataToMap(call))
            } else {
                promise.resolve(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "getInitialCall error: ${e.message}")
            promise.reject("INITIAL_CALL_ERROR", e.message)
        }
    }

    @ReactMethod
    fun endCall(callId: String, promise: Promise) {
        try {
            RiviumPushVoip.endCall(callId)
            promise.resolve(null)
        } catch (e: Exception) {
            Log.e(TAG, "endCall error: ${e.message}")
            promise.reject("END_CALL_ERROR", e.message)
        }
    }

    @ReactMethod
    fun reportCallConnected(callId: String, promise: Promise) {
        // No-op on Android — CallKit is iOS only
        Log.d(TAG, "reportCallConnected: $callId (no-op on Android)")
        promise.resolve(null)
    }

    @ReactMethod
    fun showIncomingCall(callDataMap: ReadableMap, promise: Promise) {
        try {
            val callData = mapToCallData(callDataMap)
            RiviumPushVoip.showIncomingCall(callData)
            promise.resolve(null)
        } catch (e: Exception) {
            Log.e(TAG, "showIncomingCall error: ${e.message}")
            promise.reject("SHOW_CALL_ERROR", e.message)
        }
    }

    // ==================== Event Listeners ====================

    @ReactMethod
    fun addListener(eventName: String) {
        listenerCount++
    }

    @ReactMethod
    fun removeListeners(count: Int) {
        listenerCount -= count
    }

    // ==================== Private Helpers ====================

    private fun sendEvent(eventName: String, params: Any?) {
        reactApplicationContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, params)
    }

    private fun callDataToMap(callData: CallData): WritableMap {
        return Arguments.createMap().apply {
            putString("callId", callData.callId)
            putString("callerName", callData.callerName)
            callData.callerId?.let { putString("callerId", it) }
            callData.callerAvatar?.let { putString("callerAvatar", it) }
            putString("callType", callData.callType)
            putDouble("timestamp", callData.timestamp.toDouble())

            callData.payload?.let { payload ->
                val payloadMap = Arguments.createMap()
                payload.forEach { (k, v) ->
                    when (v) {
                        is String -> payloadMap.putString(k, v)
                        is Number -> payloadMap.putDouble(k, v.toDouble())
                        is Boolean -> payloadMap.putBoolean(k, v)
                        else -> v?.let { payloadMap.putString(k, it.toString()) }
                    }
                }
                putMap("payload", payloadMap)
            }
        }
    }

    private fun mapToCallData(map: ReadableMap): CallData {
        val payload = mutableMapOf<String, Any?>()
        if (map.hasKey("payload")) {
            map.getMap("payload")?.let { payloadMap ->
                val iterator = payloadMap.keySetIterator()
                while (iterator.hasNextKey()) {
                    val key = iterator.nextKey()
                    when (payloadMap.getType(key)) {
                        ReadableType.String -> payload[key] = payloadMap.getString(key)
                        ReadableType.Number -> payload[key] = payloadMap.getDouble(key)
                        ReadableType.Boolean -> payload[key] = payloadMap.getBoolean(key)
                        else -> {}
                    }
                }
            }
        }

        return CallData(
            callId = map.getString("callId") ?: "",
            callerName = map.getString("callerName") ?: "Unknown",
            callerId = if (map.hasKey("callerId")) map.getString("callerId") else null,
            callerAvatar = if (map.hasKey("callerAvatar")) map.getString("callerAvatar") else null,
            callType = if (map.hasKey("callType")) map.getString("callType") ?: "audio" else "audio",
            payload = if (payload.isNotEmpty()) payload else null,
            timestamp = if (map.hasKey("timestamp")) map.getDouble("timestamp").toLong() else System.currentTimeMillis()
        )
    }
}

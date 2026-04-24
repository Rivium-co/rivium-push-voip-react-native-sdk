/**
 * RiviumPush VoIP React Native SDK
 * VoIP call handling with native incoming call UI
 */

import { NativeModules, NativeEventEmitter, Platform } from 'react-native';

const { RiviumPushVoipReactNative } = NativeModules;

// Types
export interface VoipConfig {
  /** App name shown in call notification */
  appName: string;
  /** Custom ringtone URI (optional) */
  ringtoneUri?: string;
  /** Enable vibration (default: true) */
  vibrate?: boolean;
  /** Call timeout in seconds (default: 30) */
  callTimeout?: number;
  /** Key in push payload for call ID (default: 'call_id') */
  callIdKey?: string;
  /** Key in push payload for caller name (default: 'caller_name') */
  callerNameKey?: string;
  /** Key in push payload for caller ID (default: 'caller_id') */
  callerIdKey?: string;
  /** Key in push payload for caller avatar (default: 'caller_avatar') */
  callerAvatarKey?: string;
  /** Key in push payload for call type (default: 'call_type') */
  callTypeKey?: string;
}

export interface CallData {
  /** Unique call identifier */
  callId: string;
  /** Name of the caller */
  callerName: string;
  /** Caller's user ID (optional) */
  callerId?: string;
  /** Avatar URL of the caller (optional) */
  callerAvatar?: string;
  /** Type of call: 'audio' or 'video' */
  callType: 'audio' | 'video';
  /** Additional data from push payload */
  payload?: Record<string, any>;
  /** Timestamp when call was received */
  timestamp: number;
}

export type OnCallAccepted = (callData: CallData) => void;
export type OnCallDeclined = (callData: CallData) => void;
export type OnCallTimeout = (callData: CallData) => void;
export type OnError = (error: string) => void;

// Event emitter
const eventEmitter = new NativeEventEmitter(RiviumPushVoipReactNative);

// Subscription storage
let subscriptions: any[] = [];

/**
 * RiviumPush VoIP SDK for React Native
 */
class RiviumPushVoip {
  private initialized = false;

  /**
   * Initialize the VoIP SDK
   */
  async init(config: VoipConfig): Promise<void> {
    await RiviumPushVoipReactNative.init(config);
    this.initialized = true;
    console.log('[RiviumPushVoIP] Initialized');
  }

  /**
   * Set API key for VoIP token registration with server.
   * On iOS, this triggers PushKit token upload to the Rivium server.
   */
  async setApiKey(params: {
    apiKey: string;
    deviceId?: string;
    serverUrl?: string;
  }): Promise<void> {
    return RiviumPushVoipReactNative.setApiKey({
      apiKey: params.apiKey,
      deviceId: params.deviceId ?? '',
      serverUrl: params.serverUrl ?? 'https://push-api.rivium.co',
    });
  }

  /**
   * Get initial call that launched the app (if any)
   */
  async getInitialCall(): Promise<CallData | null> {
    return RiviumPushVoipReactNative.getInitialCall();
  }

  /**
   * End a call (dismiss native call UI)
   */
  async endCall(callId: string): Promise<void> {
    return RiviumPushVoipReactNative.endCall(callId);
  }

  /**
   * Report call as connected
   */
  async reportCallConnected(callId: string): Promise<void> {
    return RiviumPushVoipReactNative.reportCallConnected(callId);
  }

  /**
   * Manually show incoming call UI
   */
  async showIncomingCall(callData: CallData): Promise<void> {
    return RiviumPushVoipReactNative.showIncomingCall(callData);
  }

  /**
   * Check if SDK is initialized (JS-side)
   */
  isInitialized(): boolean {
    return this.initialized;
  }

  /**
   * Check if VoIP was previously configured (persisted native state).
   * Returns true if VoIP was initialized in a previous app session.
   */
  async isConfigured(): Promise<boolean> {
    return RiviumPushVoipReactNative.isConfigured();
  }

  /**
   * Set callback for when call is accepted
   */
  onCallAccepted(callback: OnCallAccepted): () => void {
    const subscription = eventEmitter.addListener('onCallAccepted', callback);
    subscriptions.push(subscription);
    return () => subscription.remove();
  }

  /**
   * Set callback for when call is declined
   */
  onCallDeclined(callback: OnCallDeclined): () => void {
    const subscription = eventEmitter.addListener('onCallDeclined', callback);
    subscriptions.push(subscription);
    return () => subscription.remove();
  }

  /**
   * Set callback for when call times out
   */
  onCallTimeout(callback: OnCallTimeout): () => void {
    const subscription = eventEmitter.addListener('onCallTimeout', callback);
    subscriptions.push(subscription);
    return () => subscription.remove();
  }

  /**
   * Set callback for errors
   */
  onError(callback: OnError): () => void {
    const subscription = eventEmitter.addListener('onError', callback);
    subscriptions.push(subscription);
    return () => subscription.remove();
  }

  /**
   * Remove all event listeners
   */
  removeAllListeners(): void {
    subscriptions.forEach(sub => sub.remove());
    subscriptions = [];
  }
}

// Export singleton instance
export default new RiviumPushVoip();

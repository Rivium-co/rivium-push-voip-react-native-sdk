/**
 * RiviumPush VoIP React Native SDK
 * VoIP call handling with native incoming call UI
 */

import { NativeModules, NativeEventEmitter } from 'react-native';

const { RiviumPushVoipReactNative } = NativeModules;

// Event emitter
const eventEmitter = new NativeEventEmitter(RiviumPushVoipReactNative);

// Subscription storage
let subscriptions = [];

/**
 * RiviumPush VoIP SDK for React Native
 */
class RiviumPushVoip {
  constructor() {
    this.initialized = false;
  }

  /**
   * Initialize the VoIP SDK
   */
  async init(config) {
    if (this.initialized) {
      console.log('[RiviumPushVoIP] Already initialized');
      return;
    }

    await RiviumPushVoipReactNative.init(config);
    this.initialized = true;
    console.log('[RiviumPushVoIP] Initialized');
  }

  /**
   * Get initial call that launched the app (if any)
   */
  async getInitialCall() {
    return RiviumPushVoipReactNative.getInitialCall();
  }

  /**
   * End a call (dismiss native call UI)
   */
  async endCall(callId) {
    return RiviumPushVoipReactNative.endCall(callId);
  }

  /**
   * Report call as connected
   */
  async reportCallConnected(callId) {
    return RiviumPushVoipReactNative.reportCallConnected(callId);
  }

  /**
   * Manually show incoming call UI
   */
  async showIncomingCall(callData) {
    return RiviumPushVoipReactNative.showIncomingCall(callData);
  }

  /**
   * Check if SDK is initialized
   */
  isInitialized() {
    return this.initialized;
  }

  /**
   * Set callback for when call is accepted
   */
  onCallAccepted(callback) {
    const subscription = eventEmitter.addListener('onCallAccepted', callback);
    subscriptions.push(subscription);
    return () => subscription.remove();
  }

  /**
   * Set callback for when call is declined
   */
  onCallDeclined(callback) {
    const subscription = eventEmitter.addListener('onCallDeclined', callback);
    subscriptions.push(subscription);
    return () => subscription.remove();
  }

  /**
   * Set callback for when call times out
   */
  onCallTimeout(callback) {
    const subscription = eventEmitter.addListener('onCallTimeout', callback);
    subscriptions.push(subscription);
    return () => subscription.remove();
  }

  /**
   * Set callback for errors
   */
  onError(callback) {
    const subscription = eventEmitter.addListener('onError', callback);
    subscriptions.push(subscription);
    return () => subscription.remove();
  }

  /**
   * Remove all event listeners
   */
  removeAllListeners() {
    subscriptions.forEach(sub => sub.remove());
    subscriptions = [];
  }
}

// Export singleton instance
export default new RiviumPushVoip();

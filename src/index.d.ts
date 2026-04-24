/**
 * RiviumPush VoIP React Native SDK Type Definitions
 */

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

interface RiviumPushVoip {
  /**
   * Initialize the VoIP SDK
   */
  init(config: VoipConfig): Promise<void>;

  /**
   * Set API key for VoIP token registration with server.
   * On iOS, this triggers PushKit token upload to the Rivium server.
   */
  setApiKey(params: {
    apiKey: string;
    deviceId?: string;
    serverUrl?: string;
  }): Promise<void>;

  /**
   * Get initial call that launched the app (if any)
   */
  getInitialCall(): Promise<CallData | null>;

  /**
   * End a call (dismiss native call UI)
   */
  endCall(callId: string): Promise<void>;

  /**
   * Report call as connected
   */
  reportCallConnected(callId: string): Promise<void>;

  /**
   * Manually show incoming call UI
   */
  showIncomingCall(callData: CallData): Promise<void>;

  /**
   * Check if SDK is initialized
   */
  isInitialized(): boolean;

  /**
   * Set callback for when call is accepted
   */
  onCallAccepted(callback: OnCallAccepted): () => void;

  /**
   * Set callback for when call is declined
   */
  onCallDeclined(callback: OnCallDeclined): () => void;

  /**
   * Set callback for when call times out
   */
  onCallTimeout(callback: OnCallTimeout): () => void;

  /**
   * Set callback for errors
   */
  onError(callback: OnError): () => void;

  /**
   * Remove all event listeners
   */
  removeAllListeners(): void;
}

declare const RiviumPushVoip: RiviumPushVoip;
export default RiviumPushVoip;

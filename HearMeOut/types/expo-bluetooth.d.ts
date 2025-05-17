declare module 'expo-bluetooth' {
  export interface BluetoothPermissionResponse {
    granted: boolean;
  }

  export interface DiscoveryOptions {
    lowEnergy?: boolean;
    allowDuplicates?: boolean;
  }

  export interface BluetoothEventSubscription {
    remove(): void;
  }

  export function isLowEnergySupported(): Promise<boolean>;
  export function requestPermissionsAsync(): Promise<BluetoothPermissionResponse>;
  export function startDiscoveryAsync(options?: DiscoveryOptions): Promise<void>;
  export function stopDiscoveryAsync(): Promise<void>;
  export function connectAsync(deviceId: string): Promise<void>;
  export function disconnectAsync(deviceId: string): Promise<void>;
  export function addListener(
    eventName: 'discovery',
    listener: (event: { device: { id: string; name: string | null } }) => void
  ): BluetoothEventSubscription;
} 
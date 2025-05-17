import React, { createContext, useState, useContext, useEffect } from 'react';
import { Platform } from 'react-native';
import { BleManager, Device, State as BleState } from 'react-native-ble-plx';
import { useSettings } from './SettingsContext';
import * as Permissions from 'expo-permissions';

// Define Bluetooth device type
export interface BluetoothDevice {
  id: string;
  name: string | null;
  isConnected: boolean;
  rssi?: number;
}

// Bluetooth connection states
export type ConnectionState = 'disconnected' | 'connecting' | 'connected' | 'error';

// Context type
interface BluetoothContextType {
  manager: BleManager | null;
  isBluetoothEnabled: boolean;
  connectionState: ConnectionState;
  currentDevice: BluetoothDevice | null;
  discoveredDevices: BluetoothDevice[];
  error: string | null;
  scanForDevices: () => void;
  stopScan: () => void;
  connectToDevice: (deviceId: string) => Promise<boolean>;
  disconnectDevice: () => Promise<void>;
  isScanning: boolean;
}

// Create context with default values
const BluetoothContext = createContext<BluetoothContextType>({
  manager: null,
  isBluetoothEnabled: false,
  connectionState: 'disconnected',
  currentDevice: null,
  discoveredDevices: [],
  error: null,
  scanForDevices: () => {},
  stopScan: () => {},
  connectToDevice: async () => false,
  disconnectDevice: async () => {},
  isScanning: false,
});

// Provider component
export const BluetoothProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [manager, setManager] = useState<BleManager | null>(null);
  const [isBluetoothEnabled, setIsBluetoothEnabled] = useState<boolean>(false);
  const [connectionState, setConnectionState] = useState<ConnectionState>('disconnected');
  const [currentDevice, setCurrentDevice] = useState<BluetoothDevice | null>(null);
  const [discoveredDevices, setDiscoveredDevices] = useState<BluetoothDevice[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isScanning, setIsScanning] = useState<boolean>(false);
  
  const { settings } = useSettings();

  // Initialize BLE manager
  useEffect(() => {
    const bleManager = new BleManager();
    setManager(bleManager);

    // Check initial Bluetooth state
    bleManager.state().then(state => {
      setIsBluetoothEnabled(state === BleState.PoweredOn);
    });

    // Subscribe to state changes
    const subscription = bleManager.onStateChange(state => {
      setIsBluetoothEnabled(state === BleState.PoweredOn);
    }, true);

    // Clean up
    return () => {
      subscription.remove();
      bleManager.destroy();
    };
  }, []);

  // Try to auto-connect to previous device
  useEffect(() => {
    const autoConnect = async () => {
      if (
        manager && 
        isBluetoothEnabled && 
        settings.autoConnect && 
        settings.previousDeviceId && 
        connectionState === 'disconnected'
      ) {
        try {
          await connectToDevice(settings.previousDeviceId);
        } catch (error) {
          console.log('Auto-connect failed:', error);
        }
      }
    };

    autoConnect();
  }, [manager, isBluetoothEnabled, settings.autoConnect, settings.previousDeviceId]);

  // Request Bluetooth permissions
  const requestPermissions = async () => {
    if (Platform.OS === 'android') {
      const bluetoothPermission = await Permissions.askAsync(Permissions.LOCATION);
      return bluetoothPermission.status === 'granted';
    }
    return true;
  };

  // Scan for devices
  const scanForDevices = async () => {
    if (!manager) return;
    
    // Request permissions first
    const hasPermission = await requestPermissions();
    if (!hasPermission) {
      setError('Bluetooth permission denied');
      return;
    }

    if (isBluetoothEnabled) {
      try {
        setIsScanning(true);
        setError(null);
        
        // Clear previous devices
        setDiscoveredDevices([]);
        
        // Start scanning
        manager.startDeviceScan(null, null, (error, device) => {
          if (error) {
            setError(error.message);
            stopScan();
            return;
          }

          if (device && device.name) {
            // Add device if it has a name and isn't already in the list
            device.isConnected().then(isConnected => {
              setDiscoveredDevices(prev => {
                const exists = prev.some(d => d.id === device.id);
                if (exists) return prev;
                
                return [...prev, {
                  id: device.id,
                  name: device.name,
                  isConnected,
                  rssi: device.rssi ?? undefined,
                }];
              });
            });
          }
        });

        // Stop scan after 10 seconds
        setTimeout(() => {
          stopScan();
        }, 10000);
      } catch (error: any) {
        setError(error.message || 'Failed to scan for devices');
        stopScan();
      }
    } else {
      setError('Bluetooth is not enabled');
    }
  };

  // Stop scanning
  const stopScan = () => {
    if (manager) {
      manager.stopDeviceScan();
      setIsScanning(false);
    }
  };

  // Connect to a device
  const connectToDevice = async (deviceId: string): Promise<boolean> => {
    if (!manager || !isBluetoothEnabled) {
      setError('Bluetooth is not available');
      return false;
    }

    try {
      setConnectionState('connecting');
      setError(null);

      // Stop scanning first
      stopScan();

      // Connect to the device
      const device = await manager.connectToDevice(deviceId);
      console.log('Connected to device:', device.name);
      
      // Discover services and characteristics
      await device.discoverAllServicesAndCharacteristics();
      
      // Set as current device
      setCurrentDevice({
        id: device.id,
        name: device.name,
        isConnected: true,
      });
      
      setConnectionState('connected');
      
      // Monitor disconnect
      device.onDisconnected(() => {
        console.log('Device disconnected:', device.name);
        setCurrentDevice(null);
        setConnectionState('disconnected');
      });

      return true;
    } catch (error: any) {
      console.error('Connection error:', error);
      setError(error.message || 'Failed to connect to device');
      setConnectionState('error');
      return false;
    }
  };

  // Disconnect from current device
  const disconnectDevice = async (): Promise<void> => {
    if (!manager || !currentDevice) return;
    
    try {
      await manager.cancelDeviceConnection(currentDevice.id);
      setCurrentDevice(null);
      setConnectionState('disconnected');
    } catch (error: any) {
      setError(error.message || 'Failed to disconnect from device');
    }
  };

  // Context value
  const value = {
    manager,
    isBluetoothEnabled,
    connectionState,
    currentDevice,
    discoveredDevices,
    error,
    scanForDevices,
    stopScan,
    connectToDevice,
    disconnectDevice,
    isScanning,
  };

  return (
    <BluetoothContext.Provider value={value}>
      {children}
    </BluetoothContext.Provider>
  );
};

// Custom hook to use the Bluetooth context
export const useBluetooth = () => useContext(BluetoothContext);

export default BluetoothContext;
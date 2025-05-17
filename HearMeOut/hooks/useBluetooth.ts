import { useCallback, useEffect, useState } from 'react';
import { Alert } from 'react-native';

export interface BluetoothDevice {
  id: string;
  name: string | null;
  isConnected: boolean;
}

// Mock data for simulating Bluetooth devices
const MOCK_DEVICES = [
  { id: 'device-1', name: 'HearMeOut Earbuds', isConnected: false },
  { id: 'device-2', name: 'Kitchen Speaker', isConnected: false },
  { id: 'device-3', name: 'Living Room Audio', isConnected: false },
  { id: 'device-4', name: 'Car Bluetooth', isConnected: false },
];

export const useBluetooth = () => {
  const [isScanning, setIsScanning] = useState(false);
  const [devices, setDevices] = useState<BluetoothDevice[]>([]);
  const [permissionGranted, setPermissionGranted] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);

  // Mock permissions request
  const requestPermissions = useCallback(async () => {
    // Simulate a delay and success
    await new Promise(resolve => setTimeout(resolve, 500));
    setPermissionGranted(true);
    return true;
  }, []);

  // Mock initialization
  useEffect(() => {
    const initialize = async () => {
      try {
        // Simulate initialization delay
        await new Promise(resolve => setTimeout(resolve, 1000));
        setIsInitialized(true);
      } catch (error) {
        console.error('Failed to initialize Bluetooth:', error);
        Alert.alert('Error', 'Failed to initialize Bluetooth. Please restart the app.');
      }
    };

    initialize();
  }, []);

  // Mock scan start
  const startScan = useCallback(async () => {
    if (!isInitialized) {
      Alert.alert('Error', 'Bluetooth is not initialized');
      return;
    }

    try {
      setIsScanning(true);
      setDevices([]); // Clear previous devices

      // Simulate device discovery with different delays for realism
      const discoveryTimers: ReturnType<typeof setTimeout>[] = [];
      
      // Get randomized subset of devices (2-4)
      const availableDevices = [...MOCK_DEVICES]
        .sort(() => 0.5 - Math.random())
        .slice(0, Math.floor(Math.random() * 3) + 2);
      
      availableDevices.forEach((device, index) => {
        const timer = setTimeout(() => {
          setDevices(prev => {
            if (prev.some(d => d.id === device.id)) return prev;
            return [...prev, { ...device, isConnected: false }];
          });
        }, (index + 1) * 1500); // Discover devices at intervals
        
        discoveryTimers.push(timer);
      });

      // Stop scanning after 8 seconds
      const stopTimer = setTimeout(() => {
        stopScan();
      }, 8000);

      return () => {
        // Clean up timers if scan stopped early
        discoveryTimers.forEach(clearTimeout);
        clearTimeout(stopTimer);
      };
    } catch (error) {
      console.error('Error starting scan:', error);
      setIsScanning(false);
      Alert.alert('Error', 'Failed to start scanning for devices');
    }
  }, [isInitialized]);

  // Mock scan stop
  const stopScan = useCallback(() => {
    setIsScanning(false);
  }, []);

  // Mock connect to device
  const connectToDevice = useCallback(async (deviceId: string) => {
    try {
      // Simulate connection delay
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      setDevices(prevDevices =>
        prevDevices.map(d =>
          d.id === deviceId ? { ...d, isConnected: true } : { ...d, isConnected: false }
        )
      );
      return true;
    } catch (error) {
      console.error('Connection error:', error);
      Alert.alert('Connection Error', 'Failed to connect to device');
      return false;
    }
  }, []);

  // Mock disconnect from device
  const disconnectDevice = useCallback(async (deviceId: string) => {
    try {
      // Simulate disconnection delay
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      setDevices(prevDevices =>
        prevDevices.map(d =>
          d.id === deviceId ? { ...d, isConnected: false } : d
        )
      );
      return true;
    } catch (error) {
      console.error('Disconnection error:', error);
      Alert.alert('Disconnection Error', 'Failed to disconnect from device');
      return false;
    }
  }, []);

  return {
    isScanning,
    devices,
    permissionGranted,
    isInitialized,
    startScan,
    stopScan,
    connectToDevice,
    disconnectDevice,
    requestPermissions,
  };
}; 
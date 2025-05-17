import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { GradientBackground } from '@/components/ui/GradientBackground';
import { Colors } from '@/constants/Colors';
import { BluetoothDevice, useBluetooth } from '@/hooks/useBluetooth';
import { useColorScheme } from '@/hooks/useColorScheme';
import { Ionicons } from '@expo/vector-icons';
import { BlurView } from 'expo-blur';
import * as Haptics from 'expo-haptics';
import { useEffect } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
  useWindowDimensions
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

export default function BluetoothScreen() {
  const {
    isScanning,
    devices,
    permissionGranted,
    isInitialized,
    startScan,
    stopScan,
    connectToDevice,
    disconnectDevice,
    requestPermissions,
  } = useBluetooth();

  const insets = useSafeAreaInsets();
  const colorScheme = useColorScheme();
  const colors = Colors[colorScheme ?? 'light'];
  const { width } = useWindowDimensions();

  // Request permissions when component mounts and BLE is initialized
  useEffect(() => {
    if (isInitialized) {
      requestPermissions();
    }
  }, [isInitialized, requestPermissions]);

  const handleConnect = async (deviceId: string) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    const device = devices.find(d => d.id === deviceId);
    if (!device) return;

    if (device.isConnected) {
      await disconnectDevice(deviceId);
    } else {
      await connectToDevice(deviceId);
    }
  };

  const handleScan = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (isScanning) {
      stopScan();
    } else {
      startScan();
    }
  };

  const renderDevice = ({ item }: { item: BluetoothDevice }) => (
    <Card variant="elevated" style={styles.deviceItem}>
      <Pressable
        onPress={() => handleConnect(item.id)} 
        style={({ pressed }) => pressed ? styles.pressed : undefined}
      >
        <View style={styles.deviceContent}>
          <View style={styles.deviceInfo}>
            <View style={styles.deviceIcon}>
              <Ionicons 
                name={item.isConnected ? "bluetooth" : "bluetooth-outline"} 
                size={28} 
                color={item.isConnected ? colors.tint : colors.muted} 
              />
            </View>
            <View>
              <Text style={[styles.deviceName, { color: colors.text }]}>
                {item.name}
              </Text>
              <Text style={[styles.deviceStatus, { color: colors.muted }]}>
                {item.isConnected ? 'Connected' : 'Available'}
              </Text>
            </View>
          </View>
          
          <Button
            title={item.isConnected ? 'Disconnect' : 'Connect'}
            variant={item.isConnected ? 'outline' : 'primary'}
            size="small"
            icon={item.isConnected ? "close-circle-outline" : "link-outline"}
            onPress={() => handleConnect(item.id)}
          />
        </View>
      </Pressable>
    </Card>
  );

  const getConnectionStatus = () => {
    if (!isInitialized) return 'Initializing Bluetooth...';
    if (!permissionGranted) return 'Permission Required';
    const connectedDevice = devices.find(d => d.isConnected);
    if (connectedDevice) return `Connected to ${connectedDevice.name}`;
    return 'Disconnected';
  };

  if (!isInitialized) {
    return (
      <GradientBackground variant="secondary" style={styles.loadingContainer}>
        <View style={styles.loadingContent}>
          <ActivityIndicator size="large" color={colors.tint} />
          <Text style={[styles.loadingText, { color: colors.text }]}>
            Initializing Bluetooth...
          </Text>
        </View>
      </GradientBackground>
    );
  }

  const connected = devices.some(d => d.isConnected);
  const connectedDevice = devices.find(d => d.isConnected);

  return (
    <GradientBackground style={styles.container}>
      {/* Status Bar */}
      <BlurView 
        intensity={80} 
        tint={colorScheme === 'dark' ? 'dark' : 'light'} 
        style={[
          styles.statusBar,
          { paddingTop: insets.top > 0 ? insets.top : 20 }
        ]}
      >
        <View style={styles.statusContent}>
          <View style={[
            styles.statusIndicator,
            connected ? styles.statusConnected : styles.statusDisconnected,
            { backgroundColor: connected ? colors.success : colors.muted }
          ]} />
          <Text style={[styles.statusText, { color: colors.text }]}>
            {getConnectionStatus()}
          </Text>
        </View>
      </BlurView>

      {/* Main Content */}
      <View style={styles.content}>
        {/* Device List */}
        <View style={styles.deviceList}>
          <Text style={[styles.sectionTitle, { color: colors.text }]}>
            Available Devices
          </Text>
          
          {devices.length === 0 ? (
            <View style={styles.emptyState}>
              <Ionicons 
                name={isScanning ? "search" : "bluetooth-outline"} 
                size={64} 
                color={colors.muted} 
              />
              <Text style={[styles.emptyStateTitle, { color: colors.text }]}>
                {isScanning ? 'Searching for devices...' : 'No devices found'}
              </Text>
              <Text style={[styles.emptyStateDescription, { color: colors.muted }]}>
                {!permissionGranted
                  ? 'Bluetooth permission is required to discover devices'
                  : isScanning 
                    ? 'Please wait while we look for available Bluetooth devices' 
                    : 'Tap the scan button to search for nearby devices'}
              </Text>
            </View>
          ) : (
            <FlatList
              data={devices}
              renderItem={renderDevice}
              keyExtractor={item => item.id}
              contentContainerStyle={styles.listContent}
            />
          )}
        </View>

        {/* Action Button */}
        <View style={styles.actionContainer}>
          <Button
            title={isScanning ? 'Stop Scanning' : 'Scan for Devices'}
            variant="primary"
            size="large"
            icon={isScanning ? "stop-circle" : "scan"}
            onPress={handleScan}
            loading={isScanning}
            disabled={!permissionGranted || !isInitialized}
            style={{ width: width * 0.8 }}
          />
        </View>
      </View>
    </GradientBackground>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingContent: {
    alignItems: 'center',
    gap: 16,
  },
  loadingText: {
    fontSize: 18,
    fontWeight: '500',
  },
  pressed: {
    opacity: 0.8,
  },
  statusBar: {
    paddingBottom: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(150, 150, 150, 0.2)',
  },
  statusContent: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 8,
  },
  statusIndicator: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: 8,
  },
  statusConnected: {
    shadowColor: '#4CAF50',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.5,
    shadowRadius: 5,
    elevation: 5,
  },
  statusDisconnected: {
    opacity: 0.7,
  },
  statusText: {
    fontSize: 16,
    fontWeight: '500',
  },
  content: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 20,
  },
  deviceList: {
    flex: 1,
  },
  listContent: {
    paddingBottom: 20,
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  deviceItem: {
    marginVertical: 8,
  },
  deviceContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  deviceInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  deviceIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(0, 0, 0, 0.05)',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  deviceName: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 4,
  },
  deviceStatus: {
    fontSize: 14,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 40,
  },
  emptyStateTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginTop: 24,
    marginBottom: 8,
    textAlign: 'center',
  },
  emptyStateDescription: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 22,
  },
  actionContainer: {
    paddingVertical: 24,
    alignItems: 'center',
  },
}); 
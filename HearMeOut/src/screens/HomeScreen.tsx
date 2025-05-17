import React, { useState, useEffect } from 'react';
import { 
  View, 
  StyleSheet, 
  ScrollView, 
  Alert, 
  Platform,
  TouchableOpacity 
} from 'react-native';
import { 
  Button, 
  Card, 
  Title, 
  Paragraph, 
  IconButton, 
  Text,
  Portal,
  Dialog,
  ActivityIndicator
} from 'react-native-paper';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';

// Import custom components
import AudioControls from '../components/AudioControls';
import ConnectionStatus from '../components/ConnectionStatus';

// Import hooks
import { useAudio } from '../contexts/AudioContext';
import { useBluetooth } from '../contexts/BluetoothContext';
import { useSettings } from '../contexts/SettingsContext';

// Import constants
import { colors } from '../constants/colors';

const HomeScreen: React.FC = () => {
  const navigation = useNavigation();
  const { settings } = useSettings();
  
  // Get audio state and functions
  const { 
    processingState, 
    audioLevel, 
    outputLevel, 
    startProcessing, 
    stopProcessing,
    pauseProcessing,
    resumeProcessing,
    error: audioError,
    modelLoaded,
    modelLoadProgress
  } = useAudio();
  
  // Get bluetooth state and functions
  const {
    connectionState,
    currentDevice,
    discoveredDevices,
    scanForDevices,
    stopScan,
    connectToDevice,
    disconnectDevice,
    error: bluetoothError,
    isScanning
  } = useBluetooth();
  
  // Local state
  const [showDeviceDialog, setShowDeviceDialog] = useState(false);
  const [isProcessingActive, setIsProcessingActive] = useState(false);
  
  // Handle audio processing state changes
  useEffect(() => {
    setIsProcessingActive(processingState === 'processing');
  }, [processingState]);
  
  // Handle errors
  useEffect(() => {
    if (audioError) {
      Alert.alert('Audio Error', audioError);
    }
    
    if (bluetoothError) {
      Alert.alert('Bluetooth Error', bluetoothError);
    }
  }, [audioError, bluetoothError]);
  
  // Open device selection dialog
  const openDeviceDialog = () => {
    scanForDevices();
    setShowDeviceDialog(true);
  };
  
  // Close device selection dialog
  const closeDeviceDialog = () => {
    stopScan();
    setShowDeviceDialog(false);
  };
  
  // Connect to selected device
  const selectDevice = async (deviceId: string) => {
    closeDeviceDialog();
    await connectToDevice(deviceId);
  };
  
  // Toggle audio processing
  const toggleProcessing = async () => {
    if (isProcessingActive) {
      await stopProcessing();
    } else {
      if (connectionState !== 'connected') {
        Alert.alert(
          'No Headphones Connected',
          'Please connect to Bluetooth headphones first.',
          [
            { 
              text: 'Connect', 
              onPress: openDeviceDialog 
            },
            {
              text: 'Cancel',
              style: 'cancel'
            }
          ]
        );
        return;
      }
      
      if (!modelLoaded) {
        Alert.alert(
          'Model Not Ready',
          'The audio processing model is not loaded yet. Please wait.'
        );
        return;
      }
      
      await startProcessing();
    }
  };
  
  // Navigate to settings
  const goToSettings = () => {
    navigation.navigate('Settings' as never);
  };
  
  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Connection Status Card */}
        <Card style={styles.card}>
          <Card.Content>
            <Title>Connection Status</Title>
            <ConnectionStatus 
              connectionState={connectionState}
              currentDevice={currentDevice}
            />
            <View style={styles.buttonRow}>
              {connectionState === 'connected' ? (
                <Button 
                  mode="outlined" 
                  onPress={() => disconnectDevice()}
                  style={styles.button}
                >
                  Disconnect
                </Button>
              ) : (
                <Button 
                  mode="contained" 
                  onPress={openDeviceDialog}
                  style={styles.button}
                  icon="bluetooth"
                >
                  Connect Headphones
                </Button>
              )}
            </View>
          </Card.Content>
        </Card>

        {/* Audio Processing Card */}
        <Card style={styles.card}>
          <Card.Content>
            <Title>Audio Enhancement</Title>
            <Paragraph>
              {isProcessingActive 
                ? 'Audio enhancement is active' 
                : 'Start audio processing to reduce background noise'}
            </Paragraph>
            
            {/* Audio Controls Component */}
            <AudioControls 
              isActive={isProcessingActive}
              audioLevel={audioLevel}
              outputLevel={outputLevel}
              onToggle={toggleProcessing}
              noiseReductionLevel={settings.noiseReductionLevel}
              speechEnhancementLevel={settings.speechEnhancementLevel}
            />
          </Card.Content>
        </Card>

        {/* Model Info Card */}
        <Card style={styles.card}>
          <Card.Content>
            <Title>Processing Model</Title>
            <View style={styles.modelInfoContainer}>
              <View style={styles.modelInfoRow}>
                <Text>Model Type:</Text>
                <Text style={styles.modelValue}>
                  {settings.modelType === 'rnnoise' ? 'RNNoise' : 
                   settings.modelType === 'deepfilternet' ? 'DeepFilterNet' : 'Demucs'}
                </Text>
              </View>
              <View style={styles.modelInfoRow}>
                <Text>Status:</Text>
                <Text style={[
                  styles.modelValue, 
                  {color: modelLoaded ? colors.success : colors.warning}
                ]}>
                  {modelLoaded ? 'Loaded' : 'Loading...'}
                </Text>
              </View>
              {!modelLoaded && (
                <View style={styles.progressContainer}>
                  <Text>{`${modelLoadProgress}%`}</Text>
                  <View style={styles.progressBar}>
                    <View 
                      style={[styles.progressFill, { width: `${modelLoadProgress}%` }]} 
                    />
                  </View>
                </View>
              )}
            </View>
          </Card.Content>
          <Card.Actions>
            <Button onPress={goToSettings}>Settings</Button>
          </Card.Actions>
        </Card>
      </ScrollView>
      
      {/* Bluetooth Device Selection Dialog */}
      <Portal>
        <Dialog
          visible={showDeviceDialog}
          onDismiss={closeDeviceDialog}
          style={styles.dialog}
        >
          <Dialog.Title>Select Headphones</Dialog.Title>
          <Dialog.Content>
            {isScanning ? (
              <View style={styles.scanningContainer}>
                <ActivityIndicator animating={true} color={colors.primary} />
                <Text style={styles.scanningText}>Scanning for devices...</Text>
              </View>
            ) : discoveredDevices.length === 0 ? (
              <Text>No devices found. Try scanning again.</Text>
            ) : (
              <ScrollView style={styles.deviceList}>
                {discoveredDevices.map((device) => (
                  <TouchableOpacity
                    key={device.id}
                    style={styles.deviceItem}
                    onPress={() => selectDevice(device.id)}
                  >
                    <View style={styles.deviceInfo}>
                      <Text style={styles.deviceName}>{device.name || 'Unknown Device'}</Text>
                      <Text style={styles.deviceId}>{device.id}</Text>
                    </View>
                    <IconButton
                      icon="chevron-right"
                      size={24}
                    />
                  </TouchableOpacity>
                ))}
              </ScrollView>
            )}
          </Dialog.Content>
          <Dialog.Actions>
            <Button onPress={isScanning ? stopScan : scanForDevices}>
              {isScanning ? 'Stop' : 'Scan'}
            </Button>
            <Button onPress={closeDeviceDialog}>Cancel</Button>
          </Dialog.Actions>
        </Dialog>
      </Portal>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  scrollContent: {
    padding: 16,
  },
  card: {
    marginBottom: 16,
    elevation: 2,
    borderRadius: 8,
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: 16,
  },
  button: {
    marginHorizontal: 8,
  },
  modelInfoContainer: {
    marginTop: 8,
  },
  modelInfoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  modelValue: {
    fontWeight: '500',
  },
  progressContainer: {
    marginTop: 8,
  },
  progressBar: {
    height: 8,
    backgroundColor: colors.divider,
    borderRadius: 4,
    marginTop: 4,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: colors.primary,
  },
  dialog: {
    borderRadius: 8,
  },
  scanningContainer: {
    alignItems: 'center',
    padding: 16,
  },
  scanningText: {
    marginTop: 8,
  },
  deviceList: {
    maxHeight: 300,
  },
  deviceItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: colors.divider,
  },
  deviceInfo: {
    flex: 1,
  },
  deviceName: {
    fontSize: 16,
    fontWeight: '500',
  },
  deviceId: {
    fontSize: 12,
    color: colors.textLight,
    marginTop: 4,
  },
});

export default HomeScreen;
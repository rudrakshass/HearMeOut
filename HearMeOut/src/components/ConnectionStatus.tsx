import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Text, Surface, Avatar } from 'react-native-paper';
import { BluetoothDevice, ConnectionState } from '../contexts/BluetoothContext';
import { colors, uiStates } from '../constants/colors';

interface ConnectionStatusProps {
  connectionState: ConnectionState;
  currentDevice: BluetoothDevice | null;
}

const ConnectionStatus: React.FC<ConnectionStatusProps> = ({
  connectionState,
  currentDevice,
}) => {
  // Get UI state colors based on connection state
  const getStateColors = () => {
    switch (connectionState) {
      case 'connected':
        return uiStates.connected;
      case 'connecting':
        return uiStates.connecting;
      case 'disconnected':
      case 'error':
      default:
        return uiStates.disconnected;
    }
  };
  
  // Get status text based on connection state
  const getStatusText = () => {
    switch (connectionState) {
      case 'connected':
        return 'Connected';
      case 'connecting':
        return 'Connecting...';
      case 'error':
        return 'Connection Error';
      case 'disconnected':
      default:
        return 'Disconnected';
    }
  };
  
  // Get icon based on connection state
  const getIcon = () => {
    switch (connectionState) {
      case 'connected':
        return 'bluetooth-audio';
      case 'connecting':
        return 'bluetooth-searching';
      case 'error':
        return 'bluetooth-off';
      case 'disconnected':
      default:
        return 'bluetooth-disabled';
    }
  };
  
  const stateColors = getStateColors();
  
  return (
    <Surface style={styles.container}>
      <View style={styles.statusRow}>
        {/* Status Icon */}
        <Avatar.Icon 
          icon={getIcon()} 
          size={48} 
          style={[styles.statusIcon, { backgroundColor: stateColors.background }]} 
          color={stateColors.icon}
        />
        
        {/* Status Text */}
        <View style={styles.statusTextContainer}>
          <Text style={styles.statusText}>{getStatusText()}</Text>
          
          {/* Device Name (if connected) */}
          {currentDevice && connectionState === 'connected' && (
            <Text style={styles.deviceName}>
              {currentDevice.name || 'Unknown Device'}
            </Text>
          )}
          
          {/* Device ID (if connected and in debug mode) */}
          {currentDevice && connectionState === 'connected' && (
            <Text style={styles.deviceId}>
              {currentDevice.id.substring(0, 8)}...
            </Text>
          )}
        </View>
      </View>
      
      {/* Status Indicator */}
      <View 
        style={[
          styles.indicator, 
          { backgroundColor: stateColors.background }
        ]}
      />
    </Surface>
  );
};

const styles = StyleSheet.create({
  container: {
    padding: 16,
    borderRadius: 8,
    elevation: 1,
    marginTop: 8,
    position: 'relative',
    overflow: 'hidden',
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusIcon: {
    marginRight: 16,
  },
  statusTextContainer: {
    flex: 1,
  },
  statusText: {
    fontSize: 18,
    fontWeight: '500',
  },
  deviceName: {
    marginTop: 4,
    fontSize: 14,
  },
  deviceId: {
    marginTop: 2,
    fontSize: 12,
    color: colors.textLight,
  },
  indicator: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: 4,
    height: '100%',
  },
});

export default ConnectionStatus;
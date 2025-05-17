import { Ionicons } from '@expo/vector-icons';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';

export default function BluetoothScreen() {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity style={styles.scanButton}>
          <Ionicons name="refresh" size={20} color="#fff" />
          <Text style={styles.scanButtonText}>Scan for Devices</Text>
        </TouchableOpacity>
      </View>
      
      <View style={styles.deviceList}>
        <Text style={styles.sectionTitle}>Connected Devices</Text>
        <Text style={styles.placeholder}>No devices connected</Text>
        
        <Text style={[styles.sectionTitle, styles.availableTitle]}>Available Devices</Text>
        <Text style={styles.placeholder}>Scanning for devices...</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  header: {
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  scanButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#4CAF50',
    padding: 12,
    borderRadius: 8,
    gap: 8,
  },
  scanButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  deviceList: {
    flex: 1,
    padding: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  availableTitle: {
    marginTop: 24,
  },
  placeholder: {
    color: '#666',
    fontSize: 16,
    fontStyle: 'italic',
  },
}); 
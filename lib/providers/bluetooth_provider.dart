import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bluetoothStateProvider = StreamProvider<BluetoothAdapterState>((ref) {
  return FlutterBluePlus.adapterState;
});

class BluetoothNotifier extends StateNotifier<BluetoothState> {
  BluetoothNotifier() : super(BluetoothState(connectedDevices: []));

  Future<void> startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    } catch (e) {
      print('Error starting scan: $e');
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Error stopping scan: $e');
    }
  }

  Future<void> connectDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      state = BluetoothState(
        connectedDevices: [...state.connectedDevices, device],
      );
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      state = BluetoothState(
        connectedDevices: state.connectedDevices.where((d) => d.id != device.id).toList(),
      );
    } catch (e) {
      print('Error disconnecting from device: $e');
    }
  }
}

class BluetoothState {
  final List<BluetoothDevice> connectedDevices;

  BluetoothState({required this.connectedDevices});
}

final bluetoothProvider = StateNotifierProvider<BluetoothNotifier, BluetoothState>((ref) {
  return BluetoothNotifier();
}); 
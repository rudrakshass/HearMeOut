import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HeadphoneBluetoothService {
  final StreamController<List<ScanResult>> _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  final StreamController<BluetoothDevice?> _connectedDeviceController = StreamController<BluetoothDevice?>.broadcast();
  final StreamController<HeadphoneConnectionState> _connectionStateController = StreamController<HeadphoneConnectionState>.broadcast();
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;

  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;
  Stream<BluetoothDevice?> get connectedDevice => _connectedDeviceController.stream;
  Stream<HeadphoneConnectionState> get connectionState => _connectionStateController.stream;

  Future<void> initialize() async {
    try {
      // Check if Bluetooth is available
      if (await FlutterBluePlus.isAvailable == false) {
        throw Exception('Bluetooth is not available on this device');
      }
      
      // Listen for connected devices
      List<BluetoothDevice> devices = await FlutterBluePlus.connectedDevices;
      if (devices.isNotEmpty) {
        _connectedDeviceController.add(devices.first);
        _connectionStateController.add(HeadphoneConnectionState.connected);
      } else {
        _connectedDeviceController.add(null);
        _connectionStateController.add(HeadphoneConnectionState.disconnected);
      }
    } catch (e) {
      print('Error initializing Bluetooth: $e');
      rethrow;
    }
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    
    try {
      _isScanning = true;
      
      // Cancel any existing scan
      await FlutterBluePlus.stopScan();
      
      // Clear previous results
      _scanResultsController.add([]);
      
      // Listen to scan results
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        // Sort by signal strength (RSSI) - higher (less negative) values are stronger
        final sortedResults = List<ScanResult>.from(results)
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        _scanResultsController.add(sortedResults);
      });

      // Start scanning with a longer timeout
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true
      );
      
    } catch (e) {
      print('Error scanning for devices: $e');
      _scanResultsController.addError(e);
    } finally {
      _isScanning = false;
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _scanSubscription = null;
    } catch (e) {
      print('Error stopping scan: $e');
    } finally {
      _isScanning = false;
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      _connectionStateController.add(HeadphoneConnectionState.connecting);
      
      // Cancel any existing connection subscription
      await _connectionSubscription?.cancel();
      
      // Listen to connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        switch (state) {
          case BluetoothConnectionState.connected:
            _connectionStateController.add(HeadphoneConnectionState.connected);
            _connectedDeviceController.add(device);
            break;
          case BluetoothConnectionState.disconnected:
            _connectionStateController.add(HeadphoneConnectionState.disconnected);
            _connectedDeviceController.add(null);
            break;
          case BluetoothConnectionState.connecting:
            _connectionStateController.add(HeadphoneConnectionState.connecting);
            break;
          case BluetoothConnectionState.disconnecting:
            _connectionStateController.add(HeadphoneConnectionState.disconnecting);
            break;
        }
      });

      // Attempt to connect with timeout
      await device.connect(timeout: const Duration(seconds: 10));
      
    } catch (e) {
      print('Error connecting to device: $e');
      _connectionStateController.add(HeadphoneConnectionState.error);
      rethrow;
    }
  }

  Future<void> disconnect(BluetoothDevice device) async {
    try {
      _connectionStateController.add(HeadphoneConnectionState.disconnecting);
      await device.disconnect();
      _connectionStateController.add(HeadphoneConnectionState.disconnected);
      _connectedDeviceController.add(null);
    } catch (e) {
      print('Error disconnecting from device: $e');
      _connectionStateController.add(HeadphoneConnectionState.error);
      rethrow;
    }
  }

  void dispose() {
    stopScan();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scanResultsController.close();
    _connectedDeviceController.close();
    _connectionStateController.close();
  }
}

enum HeadphoneConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error
} 
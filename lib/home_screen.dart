import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HeadphoneBluetoothService _bluetoothService = HeadphoneBluetoothService();
  bool _isEnhancing = false;
  double _filterAggressiveness = 0.5;
  BluetoothDevice? _connectedDevice;
  HeadphoneConnectionState _connectionState = HeadphoneConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    try {
      await _bluetoothService.initialize();
      _bluetoothService.connectedDevice.listen((device) {
        setState(() {
          _connectedDevice = device;
        });
      });
      _bluetoothService.connectionState.listen((state) {
        setState(() {
          _connectionState = state;
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing Bluetooth: $e')),
        );
      }
    }
  }

  Widget _buildConnectionButton(BluetoothDevice device) {
    switch (_connectionState) {
      case HeadphoneConnectionState.connecting:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case HeadphoneConnectionState.connected:
        return ElevatedButton(
          onPressed: () async {
            try {
              await _bluetoothService.disconnect(device);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error disconnecting: $e')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Disconnect'),
        );
      case HeadphoneConnectionState.disconnecting:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      default:
        return ElevatedButton(
          onPressed: () async {
            try {
              await _bluetoothService.connect(device);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error connecting: $e')),
                );
              }
            }
          },
          child: const Text('Connect'),
        );
    }
  }

  void _showDeviceList() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamBuilder<List<ScanResult>>(
          stream: _bluetoothService.scanResults,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Scanning for devices...'),
                  ],
                ),
              );
            }

            List<ScanResult> devices = snapshot.data!;
            
            if (devices.isEmpty) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Devices',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _bluetoothService.startScan(),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_searching, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No devices found'),
                          SizedBox(height: 8),
                          Text('Make sure your headphones are in pairing mode'),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Available Devices',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => _bluetoothService.startScan(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index].device;
                      final rssi = devices[index].rssi;
                      final signalStrength = rssi > -50 ? 'Excellent' :
                                          rssi > -70 ? 'Good' :
                                          rssi > -85 ? 'Fair' : 'Poor';
                      
                      final isConnected = _connectedDevice?.id == device.id;
                      
                      return ListTile(
                        leading: Icon(
                          Icons.bluetooth,
                          color: isConnected ? Theme.of(context).colorScheme.primary :
                                 rssi > -70 ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                        title: Text(
                          device.name.isNotEmpty ? device.name : 'Unknown Device',
                          style: TextStyle(
                            fontWeight: device.name.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                            color: isConnected ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (device.name.isEmpty)
                              Text('ID: ${device.id.id}'),
                            Text('Signal: $signalStrength (${rssi} dBm)'),
                            if (isConnected)
                              Text(
                                'Connected',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: _buildConnectionButton(device),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    _bluetoothService.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HearMeOut'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Headphone Status',
                          style: TextStyle(fontSize: 18),
                        ),
                        Icon(
                          Icons.headphones,
                          color: _connectedDevice != null
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connectedDevice?.name ?? 'No device connected',
                      style: TextStyle(
                        color: _connectedDevice != null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                    if (_connectedDevice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await _bluetoothService.disconnect(_connectedDevice!);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error disconnecting: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Disconnect'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter Aggressiveness',
                      style: TextStyle(fontSize: 18),
                    ),
                    Slider(
                      value: _filterAggressiveness,
                      onChanged: (value) {
                        setState(() {
                          _filterAggressiveness = value;
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Gentle'),
                        Text('Aggressive'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _connectedDevice == null
                  ? null
                  : () {
                      setState(() {
                        _isEnhancing = !_isEnhancing;
                      });
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isEnhancing
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
              ),
              child: Text(
                _isEnhancing ? 'Stop Enhancement' : 'Start Enhancement',
                style: TextStyle(
                  color: _isEnhancing
                      ? Colors.black
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDeviceList,
        child: const Icon(Icons.bluetooth_searching),
      ),
    );
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }
} 
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/audio_provider.dart';
import '../providers/bluetooth_provider.dart';

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bluetoothStatus = ref.watch(bluetoothStateProvider);
    final bluetoothState = ref.watch(bluetoothProvider);
    final bluetoothNotifier = ref.read(bluetoothProvider.notifier);
    final audioState = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HearMeOut'),
        actions: [
          StreamBuilder<BluetoothAdapterState>(
            stream: FlutterBluePlus.adapterState,
            initialData: BluetoothAdapterState.unknown,
            builder: (context, snapshot) {
              final state = snapshot.data;
              return Icon(
                state == BluetoothAdapterState.on ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: state == BluetoothAdapterState.on ? Colors.blue : Colors.grey,
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Bluetooth Status
          ListTile(
            leading: Icon(
              bluetoothStatus.value == BluetoothAdapterState.on ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: bluetoothStatus.value == BluetoothAdapterState.on ? Colors.blue : Colors.grey,
            ),
            title: Text(
              bluetoothStatus.value == BluetoothAdapterState.on ? 'Bluetooth Connected' : 'Bluetooth Disconnected',
            ),
            trailing: bluetoothStatus.value == BluetoothAdapterState.on
                ? IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => bluetoothNotifier.startScan(),
                  )
                : null,
          ),

          // Connected Devices
          if (bluetoothState.connectedDevices.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Connected Devices',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView(
                children: bluetoothState.connectedDevices.map((device) => ListTile(
                  leading: const Icon(Icons.bluetooth_audio),
                  title: Text(device.name.isEmpty ? 'Unknown Device' : device.name),
                  subtitle: Text(device.id.id),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off),
                    onPressed: () => bluetoothNotifier.disconnectDevice(device),
                  ),
                )).toList(),
              ),
            ),
          ],

          // Audio Controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: audioNotifier.toggleRecording,
                  icon: Icon(audioState.isRecording ? Icons.stop : Icons.mic),
                  label: Text(audioState.isRecording ? 'Stop' : 'Start'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: Icons.mic,
                      label: 'Record',
                      isActive: audioState.isRecording,
                    ),
                    _buildControlButton(
                      icon: Icons.play_arrow,
                      label: 'Play',
                      isActive: audioState.isPlaying,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isActive ? Colors.blue : Colors.grey,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.blue : Colors.grey,
          ),
        ),
      ],
    );
  }
} 
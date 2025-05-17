import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ai_service.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final StreamController<List<int>> _audioStreamController = StreamController<List<int>>.broadcast();
  final AIService _aiService = AIService();
  bool _isInitialized = false;

  Stream<List<int>> get audioStream => _audioStreamController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }

    // Initialize AI service
    await _aiService.initialize();
    await _recorder.openRecorder();
    _isInitialized = true;
  }

  Future<void> startRecording() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Configure recorder for PCM format
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    
    // Start recording with PCM format
    await _recorder.startRecorder(
      toStream: true,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );

    // Listen to audio data and add to stream
    _recorder.onProgress!.listen((event) async {
      if (event.decodedBuffer != null) {
        // Process the audio buffer using AI model
        final enhancedBuffer = await _aiService.runModel(event.decodedBuffer!);
        _audioStreamController.add(enhancedBuffer);
      }
    });
  }

  Future<void> stopRecording() async {
    if (!_isInitialized) return;

    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    _isInitialized = false;
  }

  Future<void> dispose() async {
    await stopRecording();
    await _aiService.dispose();
    await _audioStreamController.close();
  }
} 
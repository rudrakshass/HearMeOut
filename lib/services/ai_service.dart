import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class AIService {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  /// Initialize TensorFlow Lite and load the model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the model from assets
      final modelBytes = await rootBundle.load('assets/models/noise_reduction_model.tflite');
      final modelData = modelBytes.buffer.asUint8List();

      // Create interpreter options
      final interpreterOptions = InterpreterOptions()
        ..threads = 1;

      // Create the interpreter
      _interpreter = await Interpreter.fromBuffer(modelData, options: interpreterOptions);
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize TensorFlow Lite model: $e');
    }
  }

  /// Run inference on the audio buffer
  /// Returns the enhanced audio buffer
  Future<List<int>> runModel(List<int> inputBuffer) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Convert input buffer to Float32List for model input
      final Float32List inputData = Float32List.fromList(
        inputBuffer.map((x) => x / 32768.0).toList(), // Normalize to [-1, 1]
      );

      // Prepare input tensor
      final inputShape = [1, inputData.length]; // Shape: [batch_size, sequence_length]
      final inputTensor = inputData.buffer.asFloat32List();

      // Prepare output tensor
      final outputShape = [1, inputData.length];
      final outputTensor = Float32List(inputData.length);

      // Run inference
      _interpreter.run(inputTensor.buffer, outputTensor.buffer);

      // Convert back to int16 and denormalize
      final List<int> enhancedBuffer = outputTensor
          .map((x) => (x * 32768.0).clamp(-32768, 32767).toInt())
          .toList();

      return enhancedBuffer;
    } catch (e) {
      throw Exception('Failed to run model inference: $e');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    if (_isInitialized) {
      _interpreter.close();
      _isInitialized = false;
    }
  }
} 
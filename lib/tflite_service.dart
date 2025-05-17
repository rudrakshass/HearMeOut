import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  static Interpreter? _interpreter;
  
  // Get the loaded interpreter
  static Interpreter? get interpreter => _interpreter;
  
  // Flag to check if model is loaded
  static bool _modelLoaded = false;
  static bool get isModelLoaded => _modelLoaded;

  // Model loading method
  static Future<void> loadModel() async {
    try {
      // Clear any existing interpreter
      _interpreter?.close();
      
      // Set custom options if needed
      final options = InterpreterOptions();
      
      // Load the model from assets
      _interpreter = await Interpreter.fromAsset(
        'assets/models/model.tflite',
        options: options,
      );
      
      // Get model input and output shapes and types for inference
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      
      debugPrint('TFLite model loaded successfully');
      debugPrint('Input shape: $inputShape');
      debugPrint('Output shape: $outputShape');
      
      _modelLoaded = true;
    } catch (e) {
      debugPrint('Error while loading TFLite model: $e');
      _modelLoaded = false;
    }
  }
  
  // Cleanup resources
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
  }
}

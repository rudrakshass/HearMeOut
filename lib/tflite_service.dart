import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'image_converter.dart';

class TFLiteService {
  static Interpreter? _interpreter;
  
  // Get the loaded interpreter
  static Interpreter? get interpreter => _interpreter;
  
  // Flag to check if model is loaded
  static bool _modelLoaded = false;
  static bool get isModelLoaded => _modelLoaded;
  
  // Input shape for the model
  static List<int> _inputShape = [];
  static List<int> get inputShape => _inputShape;
  
  // Output shape for the model
  static List<int> _outputShape = [];
  static List<int> get outputShape => _outputShape;

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
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      
      debugPrint('TFLite model loaded successfully');
      debugPrint('Input shape: $_inputShape');
      debugPrint('Output shape: $_outputShape');
      
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
  
  /// Run inference on a camera image
  static Future<List<dynamic>> runInferenceOnCameraImage(CameraImage cameraImage) async {
    if (!_modelLoaded || _interpreter == null) {
      throw Exception('TFLite model not loaded');
    }
    
    // Get input dimensions from model
    final int inputWidth = _inputShape[1]; // Height x Width format
    final int inputHeight = _inputShape[2];
    // Check if model is quantized (uint8) or float (float32)
    final bool isQuantized = _interpreter!.getInputTensor(0).type == TfLiteType.uint8;
    
    // Convert camera image to tensor input format
    final List<double> inputTensor = ImageConverter.imageToTensorInput(
      cameraImage,
      inputWidth,
      inputHeight,
      normalize: !isQuantized, // Normalize if not using quantized model
    );
    
    // Prepare output buffer based on output tensor shape
    final outputBuffer = List<dynamic>.filled(
      _outputShape.reduce((a, b) => a * b),
      isQuantized ? 0 : 0.0,
    );
    
    // Run inference
    try {
      final inputs = [inputTensor];
      final outputs = {0: outputBuffer};
      
      _interpreter!.runForMultipleInputs(inputs, outputs);
      
      return outputBuffer;
    } catch (e) {
      debugPrint('Error running inference: $e');
      rethrow;
    }
  }
  
  /// Process a camera image and return results in RGB format
  static Future<Uint8List> processImageForTFLite(CameraImage cameraImage) async {
    if (!_modelLoaded) {
      throw Exception('Model not loaded');
    }
    
    // Get input dimensions from model
    final int inputWidth = _inputShape[1];
    final int inputHeight = _inputShape[2];
    
    // Convert YUV to RGB and resize to model input dimensions
    return ImageConverter.convertYUV420toRGB(
      cameraImage,
      targetWidth: inputWidth,
      targetHeight: inputHeight,
    );
  }
}

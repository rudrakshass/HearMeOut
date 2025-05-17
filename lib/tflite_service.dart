import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'image_converter.dart';
import 'detection_labels.dart';

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
  
  /// Process a preprocessed image tensor through a TFLite object detection model
  /// Returns a map containing detected objects with their bounding boxes, classes, and scores
  static Future<Map<String, dynamic>> runObjectDetection({
    required List<double> inputTensor,
    int numResults = 10,
    double threshold = 0.5,
  }) async {
    if (!_modelLoaded || _interpreter == null) {
      return {'error': 'Model not loaded'};
    }
    
    try {
      // Create output tensors based on standard object detection model format
      // Typical SSD/YOLO models produce outputs in this format:
      // [1, numBoxes, 4] for the locations (bounding boxes) 
      // [1, numBoxes] for the classes
      // [1, numBoxes] for the scores
      
      final outputLocations = List<List<List<double>>>.filled(
        1, 
        List<List<double>>.filled(
          numResults, 
          List<double>.filled(4, 0.0),
        ),
      );
      
      final outputClasses = List<List<double>>.filled(
        1, 
        List<double>.filled(numResults, 0.0),
      );
      
      final outputScores = List<List<double>>.filled(
        1, 
        List<double>.filled(numResults, 0.0),
      );
      
      // Prepare input tensor for the model
      final reshapedInput = _reshapeInputTensor(inputTensor);
      
      // Run inference
      final outputs = <int, Object>{};
      
      // Configure outputs - this may vary based on your specific model
      // These are the standard output tensors for TFLite object detection models
      outputs[0] = outputLocations;    // Bounding box coordinates [top, left, bottom, right]
      outputs[1] = outputClasses;      // Class indices 
      outputs[2] = outputScores;       // Confidence scores
      
      // Run the model
      _interpreter!.runForMultipleInputs([reshapedInput], outputs);
      
      // Process results - filter based on confidence threshold
      final List<Map<String, dynamic>> detections = [];
      
      for (int i = 0; i < numResults; i++) {
        final score = outputScores[0][i];
        
        // Only include detections above the threshold
        if (score >= threshold) {
          final bbox = outputLocations[0][i];
          final classIndex = outputClasses[0][i].toInt();
          
          detections.add({
            'bbox': {
              'top': bbox[0],
              'left': bbox[1],
              'bottom': bbox[2],
              'right': bbox[3],
            },
            'class': classIndex,
            'score': score,
          });
        }
      }
      
      return {
        'detections': detections,
        'raw': {
          'locations': outputLocations,
          'classes': outputClasses,
          'scores': outputScores,
        }
      };
    } catch (e) {
      debugPrint('Error running object detection: $e');
      return {'error': e.toString()};
    }
  }
  
  /// Helper method to reshape a List<double> to match tensor dimensions
  static dynamic _reshapeInputTensor(List<double> flatTensor) {
    if (_inputShape.length == 4) {  // For 4D tensor [1, height, width, channels]
      final batch = _inputShape[0];
      final height = _inputShape[1];
      final width = _inputShape[2];
      final channels = _inputShape[3];
      
      final result = List.generate(
        batch,
        (_) => List.generate(
          height,
          (y) => List.generate(
            width,
            (x) => List.generate(
              channels,
              (c) => flatTensor[((y * width + x) * channels) + c],
            ),
          ),
        ),
      );
      
      return result;
    } else if (_inputShape.length == 3) {  // For 3D tensor [height, width, channels]
      final height = _inputShape[0];
      final width = _inputShape[1];
      final channels = _inputShape[2];
      
      final result = List.generate(
        height,
        (y) => List.generate(
          width,
          (x) => List.generate(
            channels,
            (c) => flatTensor[((y * width + x) * channels) + c],
          ),
        ),
      );
      
      return result;
    } else {
      throw Exception('Unsupported shape for reshaping: $_inputShape');
    }
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
  
  /// Detect objects in a camera image
  /// This is a convenience method that combines image preprocessing and inference
  static Future<Map<String, dynamic>> detectObjectsInImage(CameraImage cameraImage, {double threshold = 0.5}) async {
    if (!_modelLoaded || _interpreter == null) {
      return {'error': 'Model not loaded'};
    }
    
    try {
      // Convert image to input tensor
      final inputTensor = ImageConverter.imageToTensorInput(
        cameraImage,
        _inputShape[1], // Width
        _inputShape[2], // Height
        normalize: true,
      );
      
      // Run object detection on the input tensor
      final rawDetections = await runObjectDetection(
        inputTensor: inputTensor,
        threshold: threshold,
      );
      
      // Parse raw detections into structured objects with COCO labels
      final parsedDetections = DetectionLabels.parseDetections(
        rawDetections,
        confidenceThreshold: threshold,
      );
      
      // Convert to a readable string for TTS
      final detectionSummary = DetectionLabels.detectionsToString(parsedDetections);
      
      // Return both raw and processed results
      return {
        'raw': rawDetections,
        'detections': parsedDetections,
        'summary': detectionSummary,
      };
    } catch (e) {
      debugPrint('Error detecting objects in image: $e');
      return {'error': e.toString()};
    }
  }
}

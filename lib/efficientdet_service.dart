import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

class EfficientDetService {
  // EfficientDet-Lite0 uses 320x320 input
  static const int inputSize = 320;
  static const int numChannels = 3; // RGB
  
  // Model constants
  static const double defaultThreshold = 0.5;
  static const int maxDetections = 25; // Maximum number of detections to return
  
  // TFLite interpreter
  static Interpreter? _interpreter;
  static List<String>? _labels;
  static bool _modelLoaded = false;
  static bool get isModelLoaded => _modelLoaded;
  
  // Debugging flags
  static bool _debugMode = true;
  
  // Load the model and labels
  static Future<void> loadModel() async {
    if (_modelLoaded) {
      debugPrint('Model already loaded');
      return;
    }
    
    try {
      // Clean up previous interpreter if it exists
      _interpreter?.close();
      _interpreter = null;
      
      // Step 1: Load labels
      try {
        final labelsFile = File('assets/labels.txt');
        if (_debugMode) debugPrint('Loading labels from: ${labelsFile.absolute.path}');
        
        if (await labelsFile.exists()) {
          _labels = await labelsFile.readAsLines();
          if (_debugMode) debugPrint('✓ Loaded ${_labels!.length} labels');
        } else {
          throw Exception('Labels file not found at ${labelsFile.absolute.path}');
        }
      } catch (e) {
        debugPrint('⚠️ Error loading labels: $e');
        // Fallback to hardcoded COCO labels (first 20)
        _labels = [
          'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck',
          'boat', 'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench',
          'bird', 'cat', 'dog', 'horse', 'sheep', 'cow'
        ];
        debugPrint('✓ Using fallback labels (${_labels!.length})');
      }
      
      // Step 2: Load model
      try {
        final modelFile = File('assets/efficientdet_lite0.tflite');
        if (_debugMode) debugPrint('Loading model from: ${modelFile.absolute.path}');
        
        // Create interpreter options
        final options = InterpreterOptions()..threads = 4;
        
        if (await modelFile.exists()) {
          debugPrint('✓ Found model file, loading...');
          _interpreter = await Interpreter.fromFile(modelFile, options: options);
        } else {
          debugPrint('⚠️ Model file not found, trying asset loading...');
          _interpreter = await Interpreter.fromAsset('assets/efficientdet_lite0.tflite', options: options);
        }
        
        // Print model information for debugging
        if (_debugMode) {
          final inputTensor = _interpreter!.getInputTensor(0);
          final outputTensors = List.generate(
            _interpreter!.getOutputTensorsCount(),
            (i) => _interpreter!.getOutputTensor(i),
          );
          
          debugPrint('✓ Model loaded successfully:');
          debugPrint('  - Input: shape=${inputTensor.shape}, type=${inputTensor.type}');
          for (int i = 0; i < outputTensors.length; i++) {
            debugPrint('  - Output $i: shape=${outputTensors[i].shape}, type=${outputTensors[i].type}');
          }
        }
        
        _modelLoaded = true;
        debugPrint('✓ EfficientDet-Lite0 model ready');
      } catch (e) {
        debugPrint('❌ Failed to load model: $e');
        _modelLoaded = false;
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ Error initializing EfficientDet: $e');
      _modelLoaded = false;
    }
  }
  
  // Clean up resources
  static void dispose() {
    try {
      _interpreter?.close();
      _interpreter = null;
      _modelLoaded = false;
      debugPrint('✓ EfficientDet resources released');
    } catch (e) {
      debugPrint('⚠️ Error disposing resources: $e');
    }
  }
  
  // Main detection method: Process a camera image and return detections
  static Future<List<Detection>> detectObjects(CameraImage image) async {
    if (!_modelLoaded || _interpreter == null) {
      debugPrint('❌ Model not loaded, cannot detect objects');
      return [];
    }
    
    try {
      if (_debugMode) debugPrint('Processing image: ${image.width}x${image.height}');
      final startTime = DateTime.now();
      
      // Step 1: Process image to float tensor (1, 320, 320, 3)
      final inputBuffer = _preprocessImage(image);
      
      // Step 2: Validate input tensor
      if (_debugMode) {
        // Verify the first few values are in the [-1, 1] range
        debugPrint('Input tensor check: ${inputBuffer[0]}, ${inputBuffer[1]}, ${inputBuffer[2]}');
      }
      
      // Step 3: Allocate output tensors
      final outputLocations = List<double>.filled(1 * maxDetections * 4, 0); // Bounding boxes [top, left, bottom, right]
      final outputClasses = List<double>.filled(1 * maxDetections, 0);       // Class indices
      final outputScores = List<double>.filled(1 * maxDetections, 0);        // Confidence scores
      final numDetections = List<double>.filled(1, 0);                       // Number of detections
      
      // Step 4: Set up output map
      final outputs = {
        0: outputLocations, // boxes
        1: outputClasses,   // classes
        2: outputScores,    // scores
        3: numDetections    // num_detections
      };
      
      // Step 5: Run inference
      if (_debugMode) debugPrint('Running inference...');
      _interpreter!.runForMultipleInputs([inputBuffer], outputs);
      
      // Step 6: Process results
      final int detectionsCount = numDetections[0].round();
      if (_debugMode) debugPrint('Detected $detectionsCount objects');
      
      // Step 7: Create detection objects
      final List<Detection> detections = [];
      for (int i = 0; i < detectionsCount && i < maxDetections; i++) {
        // Get data for this detection
        final score = outputScores[i];
        if (score < defaultThreshold) continue;
        
        final classId = outputClasses[i].toInt();
        if (classId < 0 || classId >= _labels!.length) continue;
        
        final label = _labels![classId];
        
        // EfficientDet outputs normalized coordinates [top, left, bottom, right]
        final top = outputLocations[i * 4];
        final left = outputLocations[i * 4 + 1];
        final bottom = outputLocations[i * 4 + 2];
        final right = outputLocations[i * 4 + 3];
        
        // Convert to pixel coordinates
        final rect = Rect.fromLTRB(
          left * image.width,
          top * image.height,
          right * image.width,
          bottom * image.height,
        );
        
        // Create detection
        detections.add(Detection(
          bbox: rect,
          label: label,
          confidence: score,
        ));
        
        if (_debugMode) {
          debugPrint('  - ${label.padRight(15)}: ${(score * 100).toStringAsFixed(1)}% at $rect');
        }
      }
      
      // Log timing
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      if (_debugMode) debugPrint('✓ Detection completed in ${duration.inMilliseconds}ms, found ${detections.length} objects');
      
      return detections;
    } catch (e, stackTrace) {
      debugPrint('❌ Error detecting objects: $e');
      if (_debugMode) debugPrint(stackTrace.toString());
      return [];
    }
  }
  
  // Convert CameraImage to input tensor
  static Float32List _preprocessImage(CameraImage image) {
    // Create a buffer of size 1*320*320*3 = 307,200 float values
    final inputBuffer = Float32List(1 * inputSize * inputSize * numChannels);
    
    try {
      // Get image info
      final width = image.width;
      final height = image.height;
      
      // Get YUV planes
      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes[1].bytes;
      final vPlane = image.planes[2].bytes;
      
      // Get strides (how many bytes per row)
      final yRowStride = image.planes[0].bytesPerRow;
      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 2;
      
      // Compute scaling factors
      final scaleX = width / inputSize;
      final scaleY = height / inputSize;
      
      // Fill input buffer with normalized RGB values
      int bufferIndex = 0;
      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          // Get source pixel coordinates (bilinear scaling)
          final int srcX = (x * scaleX).floor().clamp(0, width - 1);
          final int srcY = (y * scaleY).floor().clamp(0, height - 1);
          
          // Compute YUV indices
          final int yIndex = srcY * yRowStride + srcX;
          
          // UV values are subsampled, so they're at half resolution
          final int uvX = (srcX / 2).floor();
          final int uvY = (srcY / 2).floor();
          final int uvIndex = uvY * uvRowStride + uvX * uvPixelStride;
          
          // Get YUV values
          final int yValue = yPlane[yIndex];
          final int uValue = uPlane[uvIndex];
          final int vValue = vPlane[uvIndex];
          
          // Convert YUV to RGB using standard conversion formula
          // R = Y + 1.402 * (V - 128)
          // G = Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)
          // B = Y + 1.772 * (U - 128)
          int r = (yValue + 1.402 * (vValue - 128)).round();
          int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round();
          int b = (yValue + 1.772 * (uValue - 128)).round();
          
          // Clamp RGB values to [0, 255]
          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);
          
          // Normalize to [-1, 1] and add to input buffer (RGB order)
          inputBuffer[bufferIndex++] = (r / 127.5) - 1.0;  // R
          inputBuffer[bufferIndex++] = (g / 127.5) - 1.0;  // G
          inputBuffer[bufferIndex++] = (b / 127.5) - 1.0;  // B
        }
      }
      
      return inputBuffer;
    } catch (e) {
      debugPrint('❌ Error preprocessing image: $e');
      // Return empty buffer on error (better error handling than crashing)
      return inputBuffer;
    }
  }
  
  // Set debug mode (for verbose logging)
  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }
}

// Detection class that holds the result of an object detection
class Detection {
  final Rect bbox;
  final String label;
  final double confidence;
  
  Detection({
    required this.bbox,
    required this.label,
    required this.confidence,
  });
  
  @override
  String toString() => '$label (${(confidence * 100).toStringAsFixed(0)}%)';
} 
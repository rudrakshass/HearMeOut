import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

class EfficientDetService {
  static Interpreter? _interpreter;
  static List<String>? _labels;
  static bool _modelLoaded = false;
  static bool get isModelLoaded => _modelLoaded;
  
  // Constants for EfficientDet-Lite0
  static const int inputSize = 320;
  static const double defaultThreshold = 0.5;
  static const int maxResults = 10;
  
  // Load model and labels
  static Future<void> loadModel() async {
    try {
      // Clear any existing interpreter
      _interpreter?.close();
      
      // Try to load labels from the text file
      try {
        final labelsFile = File('assets/labels.txt');
        debugPrint('Looking for labels at: ${labelsFile.absolute.path}');
        if (await labelsFile.exists()) {
          _labels = await labelsFile.readAsLines();
          debugPrint('Loaded ${_labels!.length} labels from file');
        } else {
          throw Exception('Labels file not found');
        }
      } catch (e) {
        debugPrint('Error loading labels file: $e, using built-in default labels');
        // Use built-in COCO labels as fallback
        _labels = [
          'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 
          'boat', 'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 
          'bird', 'cat', 'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 
          'giraffe', 'backpack', 'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 
          'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat', 'baseball glove', 
          'skateboard', 'surfboard', 'tennis racket', 'bottle', 'wine glass', 'cup', 
          'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich', 'orange', 
          'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch', 
          'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 
          'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink', 
          'refrigerator', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 
          'hair drier', 'toothbrush'
        ];
      }
      
      // Load EfficientDet-Lite0 model
      try {
        final modelFile = File('assets/efficientdet_lite0.tflite');
        debugPrint('Looking for model at: ${modelFile.absolute.path}');
        
        if (await modelFile.exists()) {
          _interpreter = await Interpreter.fromFile(modelFile);
          debugPrint('Model loaded from file');
        } else {
          // Fallback to asset loading
          _interpreter = await Interpreter.fromAsset('assets/efficientdet_lite0.tflite');
          debugPrint('Model loaded from assets');
        }
        
        // Log input and output details
        final inputShape = _interpreter!.getInputTensor(0).shape;
        final outputShapes = List.generate(
          _interpreter!.getOutputTensorsCount(),
          (i) => _interpreter!.getOutputTensor(i).shape,
        );
        
        debugPrint('Model loaded successfully:');
        debugPrint('- Input shape: $inputShape');
        debugPrint('- Output shapes: $outputShapes');
      } catch (e) {
        debugPrint('Error loading model: $e');
        rethrow;
      }
      
      _modelLoaded = true;
    } catch (e) {
      debugPrint('Failed to initialize EfficientDet: $e');
      _modelLoaded = false;
    }
  }
  
  // Cleanup resources
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
  }
  
  // Process camera image and run inference
  static Future<List<Detection>> detectObjects(CameraImage image) async {
    if (!_modelLoaded || _interpreter == null) {
      debugPrint('Model not loaded, cannot detect objects');
      return [];
    }
    
    try {
      // Convert YUV camera image to RGB
      final inputBytes = _yuvToFloat32(image);
      
      // Set up output tensors
      var outputLocations = List<double>.filled(1 * maxResults * 4, 0);
      var outputClasses = List<double>.filled(1 * maxResults, 0);
      var outputScores = List<double>.filled(1 * maxResults, 0);
      var numDetections = List<double>.filled(1, 0);
      
      // Define outputs map
      final outputs = {
        0: outputLocations,
        1: outputClasses,
        2: outputScores,
        3: numDetections
      };
      
      // Run inference
      debugPrint('Running inference...');
      _interpreter!.runForMultipleInputs([inputBytes], outputs);
      
      // Get result count
      final int numResults = numDetections[0].round();
      debugPrint('Number of detections: $numResults');
      
      // Parse results
      List<Detection> detections = [];
      for (int i = 0; i < numResults && i < maxResults; i++) {
        // Get detection data
        final score = outputScores[i];
        if (score < defaultThreshold) continue;
        
        final classId = outputClasses[i].toInt();
        if (classId < 0 || classId >= _labels!.length) continue;
        
        // Get bounding box (normalized to [0,1])
        final ymin = outputLocations[i * 4];
        final xmin = outputLocations[i * 4 + 1];
        final ymax = outputLocations[i * 4 + 2];
        final xmax = outputLocations[i * 4 + 3];
        
        // Convert to pixel coordinates
        final rect = Rect.fromLTRB(
          xmin * image.width,
          ymin * image.height,
          xmax * image.width,
          ymax * image.height,
        );
        
        // Add detection
        detections.add(Detection(
          bbox: rect,
          label: _labels![classId],
          confidence: score,
        ));
        
        debugPrint('Detection: ${_labels![classId]} (${(score * 100).toStringAsFixed(1)}%)');
      }
      
      return detections;
    } catch (e) {
      debugPrint('Error in object detection: $e');
      return [];
    }
  }
  
  // Convert YUV image to RGB Float32List
  static Float32List _yuvToFloat32(CameraImage image) {
    // Get dimensions
    final int width = image.width;
    final int height = image.height;
    
    // YUV planes
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    
    // Strides and pixel stride
    final int yStride = image.planes[0].bytesPerRow;
    final int uvStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 2;
    
    // Create buffer for RGB image
    final Float32List outputBuffer = Float32List(1 * inputSize * inputSize * 3); // 1 x height x width x 3
    
    // Calculate resize scale
    final double scaleX = width / inputSize;
    final double scaleY = height / inputSize;
    
    int outputIdx = 0;
    
    // For each pixel in the output
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        // Find the corresponding pixel in the source image
        final int srcX = math.min((x * scaleX).floor(), width - 1);
        final int srcY = math.min((y * scaleY).floor(), height - 1);
        
        // Get Y value
        final int yIndex = srcY * yStride + srcX;
        final int yValue = yPlane[yIndex];
        
        // Get UV values (downsampled by 2)
        final int uvX = (srcX / 2).floor();
        final int uvY = (srcY / 2).floor();
        final int uvIndex = uvY * uvStride + uvX * uvPixelStride;
        final int uValue = uPlane[uvIndex];
        final int vValue = vPlane[uvIndex];
        
        // Convert YUV to RGB
        int r = (yValue + 1.402 * (vValue - 128)).round();
        int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).round();
        int b = (yValue + 1.772 * (uValue - 128)).round();
        
        // Clamp values to [0, 255]
        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);
        
        // Normalize to [-1, 1] and store in output buffer
        outputBuffer[outputIdx++] = (r / 127.5) - 1.0; // R
        outputBuffer[outputIdx++] = (g / 127.5) - 1.0; // G
        outputBuffer[outputIdx++] = (b / 127.5) - 1.0; // B
      }
    }
    
    return outputBuffer;
  }
}

// Detection result class
class Detection {
  final Rect bbox;
  final String label;
  final double confidence;
  
  Detection({
    required this.bbox,
    required this.label,
    required this.confidence,
  });
} 
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:async';

class EfficientDetService {
  static Interpreter? _interpreter;
  static List<String>? _labels;
  static bool _modelLoaded = false;
  static bool get isModelLoaded => _modelLoaded;
  
  // Constants for EfficientDet-Lite0
  static const int inputSize = 320;
  static const double defaultThreshold = 0.5;
  static const int maxResults = 10;
  
  // Image processor for preprocessing
  static late ImageProcessor _imageProcessor;
  
  // Timer for throttling inference
  static Timer? _inferenceTimer;
  static const Duration inferenceInterval = Duration(milliseconds: 500);
  
  // Load model and labels
  static Future<void> loadModel() async {
    try {
      // Clear any existing interpreter
      _interpreter?.close();
      
      // Load labels
      _labels = await File('assets/labels.txt').readAsLines();
      
      // Set up image processor
      _imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(inputSize, inputSize, ResizeMethod.BILINEAR))
        .add(NormalizeOp(0, 255))
        .build();
      
      // Load model
      _interpreter = await Interpreter.fromAsset(
        'assets/efficientdet_lite0.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      
      debugPrint('EfficientDet-Lite0 model loaded successfully');
      _modelLoaded = true;
    } catch (e) {
      debugPrint('Error loading EfficientDet model: $e');
      _modelLoaded = false;
    }
  }
  
  // Cleanup resources
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
    _inferenceTimer?.cancel();
  }
  
  // Process camera image and run inference
  static Future<List<Detection>> detectObjects(CameraImage image) async {
    if (!_modelLoaded || _interpreter == null) {
      throw Exception('Model not loaded');
    }
    
    // Convert camera image to input tensor
    final inputImage = _convertCameraImageToInputImage(image);
    final tensorImage = _imageProcessor.process(inputImage);
    
    // Prepare input tensor
    final inputBuffer = tensorImage.buffer;
    final inputShape = [1, inputSize, inputSize, 3];
    final inputType = TfLiteType.float32;
    
    // Prepare output tensors
    final outputLocations = List.filled(1 * maxResults * 4, 0.0);
    final outputClasses = List.filled(1 * maxResults, 0.0);
    final outputScores = List.filled(1 * maxResults, 0.0);
    final numDetections = List.filled(1, 0.0);
    
    // Run inference
    final outputs = {
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };
    
    _interpreter!.run(inputBuffer, outputs);
    
    // Process results
    final List<Detection> detections = [];
    final int numDetected = numDetections[0].toInt();
    
    for (int i = 0; i < numDetected; i++) {
      final score = outputScores[i];
      if (score >= defaultThreshold) {
        final bbox = outputLocations.sublist(i * 4, (i + 1) * 4);
        final classId = outputClasses[i].toInt();
        
        if (classId < _labels!.length) {
          detections.add(Detection(
            bbox: Rect.fromLTRB(
              bbox[1] * image.width,
              bbox[0] * image.height,
              bbox[3] * image.width,
              bbox[2] * image.height,
            ),
            label: _labels![classId],
            confidence: score,
          ));
        }
      }
    }
    
    return detections;
  }
  
  // Convert CameraImage to InputImage
  static InputImage _convertCameraImageToInputImage(CameraImage image) {
    // Convert YUV420 to RGB
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    
    // Create InputImage from bytes
    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final InputImageRotation imageRotation = InputImageRotation.rotation0deg;
    final InputImageFormat inputImageFormat = InputImageFormat.bgra8888;
    
    final planeData = image.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();
    
    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );
    
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );
  }
}

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
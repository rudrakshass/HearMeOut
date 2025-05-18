import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'image_converter.dart';
import 'model_manager.dart';

/// Enhanced TFLite service for advanced object detection and scene description
/// Specially designed for blind users with detailed verbal descriptions
class TFLiteService {
  // Interpreter instance
  static Interpreter? _interpreter;
  
  // Flag to check if model is loaded
  static bool _modelLoaded = false;
  static bool get isModelLoaded => _modelLoaded;
  
  // Input shape for the model
  static List<int> _inputShape = [];
  
  // Output shapes for the model
  static Map<String, List<int>> _outputShapes = {};
  
  // Model configuration
  static ModelConfig? _modelConfig;
  
  // Option to verbosely describe scenes for blind users
  static bool _verboseDescription = true;
  static bool get verboseDescription => _verboseDescription;
  static set verboseDescription(bool value) => _verboseDescription = value;
  
  // Last detection results for reference
  static List<DetectedObject> _lastDetections = [];
  static List<DetectedObject> get lastDetections => _lastDetections;

  /// Initialize with a specific model type
  static Future<void> initialize({String modelType = 'efficientdet'}) async {
    try {
      await loadModel(modelType);
    } catch (e) {
      debugPrint('Error initializing TFLite service: $e');
    }
  }

  /// Load the specified model type
  static Future<void> loadModel(String modelType) async {
    try {
      // Close existing interpreter
      _interpreter?.close();
      _modelLoaded = false;
      
      // Set custom options for better performance
      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;  // Use Android Neural Networks API when available
      
      // Configure model path based on type
      String modelPath;
      int inputSize;
      
      // Use EfficientDet by default
      if (modelType == 'ssd_mobilenet') {
        modelPath = 'assets/models/model.tflite'; // Use the existing model as placeholder
        inputSize = 300;
      } else {
        // Default to the existing model
        modelPath = 'assets/models/model.tflite';
        inputSize = 300;
      }
      
      // Load the model
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: options,
      );
      
      // Get model input shape
      _inputShape = _interpreter!.getInputTensor(0).shape;
      
      // Define expected output shapes for object detection
      _outputShapes = {
        'locations': [1, 10, 4],       // Bounding box coordinates [top, left, bottom, right]
        'classes': [1, 10],            // Class indices
        'scores': [1, 10],             // Confidence scores
        'num_detections': [1],         // Number of detections
      };
      
      // Store model config for later use
      _modelConfig = ModelConfig(
        modelPath: modelPath,
        labelsPath: 'assets/models/model.tflite', // This is just a placeholder
        inputSize: inputSize,
        outputShapes: _outputShapes,
        threshold: 0.5,
        numResults: 10,
        isQuantized: true,
      );
      
      debugPrint('TFLite model ($modelType) loaded successfully');
      debugPrint('Model config: ${_modelConfig!.inputSize}x${_modelConfig!.inputSize} - ${_modelConfig!.isQuantized ? 'quantized' : 'float'}');
      debugPrint('Input shape: $_inputShape');
      
      _modelLoaded = true;
    } catch (e) {
      debugPrint('Error loading TFLite model: $e');
      _modelLoaded = false;
      rethrow;
    }
  }
  
  // Cleanup resources
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
    _lastDetections = [];
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
      final outputLocations = List<List<List<double>>>.filled(
        1, 
        List<List<double>>.filled(
          numResults, 
          List<double>.filled(4, 0.0),
        ),
      );
      
      final outputClasses = List<List<int>>.filled(
        1, 
        List<int>.filled(numResults, 0),
      );
      
      final outputScores = List<List<double>>.filled(
        1, 
        List<double>.filled(numResults, 0.0),
      );
      
      final outputNumDetections = List<double>.filled(1, 0.0);
      
      // Prepare input tensor for the model
      final reshapedInput = _reshapeInputTensor(inputTensor);
      
      // Run inference
      final outputs = <int, Object>{};
      
      // Configure outputs based on model structure
      outputs[0] = outputLocations;    // Bounding box coordinates [top, left, bottom, right]
      outputs[1] = outputClasses;      // Class indices 
      outputs[2] = outputScores;       // Confidence scores
      outputs[3] = outputNumDetections; // Number of valid detections
      
      // Run the model
      _interpreter!.runForMultipleInputs([reshapedInput], outputs);
      
      // Process results - filter based on confidence threshold
      final List<Map<String, dynamic>> detections = [];
      final List<DetectedObject> detectedObjects = [];
      
      for (int i = 0; i < numResults; i++) {
        final score = outputScores[0][i];
        
        // Only include detections above the threshold
        if (score >= threshold) {
          final bbox = outputLocations[0][i];
          final classIndex = outputClasses[0][i];
          
          // Get label name (we'll use constants for now)
          final String label = _getLabelForClass(classIndex);
          
          // Store as DetectedObject for scene description
          final detectedObject = DetectedObject(
            label: label,
            confidence: score,
            boundingBox: BoundingBox(
              top: bbox[0],
              left: bbox[1],
              bottom: bbox[2],
              right: bbox[3],
            ),
          );
          detectedObjects.add(detectedObject);
          
          // Add to raw detections map for API compatibility
          detections.add({
            'score': score,
            'class': classIndex,
            'label': label,
            'bbox': {
              'top': bbox[0],
              'left': bbox[1],
              'bottom': bbox[2],
              'right': bbox[3],
            },
          });
        }
      }
      
      // Save detected objects for later reference
      _lastDetections = detectedObjects;
      
      // Generate scene description optimized for blind users
      final sceneDescription = _generateSceneDescription(detectedObjects);
      
      return {
        'detections': detections,
        'objects': detectedObjects,
        'description': sceneDescription,
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
    // Using string representation to avoid enum compatibility issues
    final bool isQuantized = _interpreter!.getInputTensor(0).type.toString().toLowerCase().contains('uint8');
    
    // Convert camera image to tensor input format
    final List<double> inputTensor = ImageConverter.imageToTensorInput(
      cameraImage,
      inputWidth,
      inputHeight,
      normalize: !isQuantized, // Normalize if not using quantized model
    );
    
    // Prepare output buffer based on output shape
    final outputSize = _outputShapes.values
        .expand((shape) => shape)
        .reduce((a, b) => a * b);
    final outputBuffer = List<dynamic>.filled(
      outputSize,
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
      
      // Generate scene description optimized for blind users
      final sceneDescription = _generateSceneDescription(_lastDetections);
      
      // Return processed results with description for blind users
      return {
        'raw': rawDetections,
        'detections': _lastDetections,
        'summary': sceneDescription,
      };
    } catch (e) {
      debugPrint('Error detecting objects in image: $e');
      return {'error': e.toString()};
    }
  }
  
  /// Get label name from class index
  static String _getLabelForClass(int classIndex) {
    // COCO dataset class labels (simplified set for common objects)
    const List<String> labels = [
      'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat',
      'traffic light', 'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird', 'cat',
      'dog', 'horse', 'sheep', 'cow', 'elephant', 'bear', 'zebra', 'giraffe', 'backpack',
      'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball',
      'kite', 'baseball bat', 'baseball glove', 'skateboard', 'surfboard', 'tennis racket', 'bottle',
      'wine glass', 'cup', 'fork', 'knife', 'spoon', 'bowl', 'banana', 'apple', 'sandwich',
      'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut', 'cake', 'chair', 'couch',
      'potted plant', 'bed', 'dining table', 'toilet', 'tv', 'laptop', 'mouse', 'remote',
      'keyboard', 'cell phone', 'microwave', 'oven', 'toaster', 'sink', 'refrigerator', 'book',
      'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush'
    ];
    
    if (classIndex >= 0 && classIndex < labels.length) {
      return labels[classIndex];
    }
    return 'unknown';
  }
  
  /// Generate a helpful scene description for blind users
  static String _generateSceneDescription(List<DetectedObject> detections) {
    if (detections.isEmpty) {
      return 'No objects detected in view.';
    }
    
    // Group objects by category
    final Map<String, List<DetectedObject>> categorizedObjects = {};
    for (final detection in detections) {
      final category = detection.label;
      if (!categorizedObjects.containsKey(category)) {
        categorizedObjects[category] = [];
      }
      categorizedObjects[category]!.add(detection);
    }
    
    // Sort categories by the highest confidence object in each category
    final sortedCategories = categorizedObjects.entries.toList()
      ..sort((a, b) {
        final maxConfidenceA = a.value.map((obj) => obj.confidence).reduce(
          (value, element) => value > element ? value : element
        );
        final maxConfidenceB = b.value.map((obj) => obj.confidence).reduce(
          (value, element) => value > element ? value : element
        );
        return maxConfidenceB.compareTo(maxConfidenceA);
      });
    
    // Build spatial description
    final StringBuffer description = StringBuffer();
    
    // Start with a general overview
    description.write(
      'I can see ${detections.length} ${detections.length == 1 ? 'object' : 'objects'}: '
    );
    
    // Add main objects (top 3 categories)
    final int categoryLimit = sortedCategories.length > 3 ? 3 : sortedCategories.length;
    for (int i = 0; i < categoryLimit; i++) {
      final category = sortedCategories[i].key;
      final count = sortedCategories[i].value.length;
      
      if (i > 0) {
        description.write(i == categoryLimit - 1 ? ' and ' : ', ');
      }
      
      description.write('$count ${count == 1 ? category : '${category}s'}');
    }
    
    // Add more detailed spatial information for the most prominent objects
    if (sortedCategories.isNotEmpty) {
      description.write('. ');
      
      // Get the most prominent category
      final mainCategory = sortedCategories[0].key;
      final mainObjects = sortedCategories[0].value;
      
      // Describe the position of the main object(s)
      if (mainObjects.length == 1) {
        final obj = mainObjects[0];
        description.write('The $mainCategory is ${_describeSpatialPosition(obj.boundingBox)}');
      } else {
        description.write('There are $mainCategory');
        description.write(mainObjects.length > 2 ? 's ' : ' ');
        description.write(_describeMultiplePositions(mainObjects));
      }
      
      // Add information about nearby objects if there are other categories
      if (sortedCategories.length > 1) {
        final secondaryCategory = sortedCategories[1].key;
        final secondaryObjects = sortedCategories[1].value;
        
        description.write('. ');
        
        if (secondaryObjects.length == 1) {
          final obj = secondaryObjects[0];
          final relation = _describeRelation(mainObjects[0].boundingBox, obj.boundingBox);
          description.write('There is a $secondaryCategory $relation');
        } else {
          description.write('There are also ${secondaryObjects.length} ${secondaryCategory}s nearby');
        }
      }
    }
    
    return description.toString();
  }
  
  /// Describe the spatial position of an object in the frame
  static String _describeSpatialPosition(BoundingBox box) {
    final centerX = (box.left + box.right) / 2;
    final centerY = (box.top + box.bottom) / 2;
    final size = (box.width * box.height);
    
    String horizontalPosition;
    if (centerX < 0.33) {
      horizontalPosition = 'on the left side';
    } else if (centerX > 0.66) {
      horizontalPosition = 'on the right side';
    } else {
      horizontalPosition = 'in the center';
    }
    
    String verticalPosition;
    if (centerY < 0.33) {
      verticalPosition = 'at the top';
    } else if (centerY > 0.66) {
      verticalPosition = 'at the bottom';
    } else {
      verticalPosition = 'in the middle';
    }
    
    String sizeDescription;
    if (size > 0.5) {
      sizeDescription = 'very close';
    } else if (size > 0.25) {
      sizeDescription = 'close';
    } else if (size > 0.1) {
      sizeDescription = 'at a moderate distance';
    } else {
      sizeDescription = 'far away';
    }
    
    return '$horizontalPosition $verticalPosition, $sizeDescription';
  }
  
  /// Describe the positions of multiple objects
  static String _describeMultiplePositions(List<DetectedObject> objects) {
    bool hasLeft = false;
    bool hasRight = false;
    bool hasCenter = false;
    bool hasTop = false;
    bool hasBottom = false;
    bool hasMiddle = false;
    
    for (final obj in objects) {
      final centerX = (obj.boundingBox.left + obj.boundingBox.right) / 2;
      final centerY = (obj.boundingBox.top + obj.boundingBox.bottom) / 2;
      
      if (centerX < 0.33) {
        hasLeft = true;
      } else if (centerX > 0.66) {
        hasRight = true;
      } else {
        hasCenter = true;
      }
      
      if (centerY < 0.33) {
        hasTop = true;
      } else if (centerY > 0.66) {
        hasBottom = true;
      } else {
        hasMiddle = true;
      }
    }
    
    final StringBuffer description = StringBuffer();
    
    // Horizontal description
    if (hasLeft && hasRight && hasCenter) {
      description.write('across the entire view');
    } else if (hasLeft && hasRight) {
      description.write('on both sides');
    } else if (hasLeft && hasCenter) {
      description.write('from the left to the center');
    } else if (hasRight && hasCenter) {
      description.write('from the center to the right');
    } else if (hasLeft) {
      description.write('on the left side');
    } else if (hasRight) {
      description.write('on the right side');
    } else if (hasCenter) {
      description.write('in the center');
    }
    
    // Add vertical description if needed
    if (hasTop && hasBottom && hasMiddle) {
      description.write(' throughout the view');
    } else if (hasTop && hasBottom) {
      description.write(' from top to bottom');
    } else if (hasTop && hasMiddle) {
      description.write(' in the upper part');
    } else if (hasBottom && hasMiddle) {
      description.write(' in the lower part');
    } else if (hasTop) {
      description.write(' at the top');
    } else if (hasBottom) {
      description.write(' at the bottom');
    }
    
    return description.toString();
  }
  
  /// Describe the spatial relation between two objects
  static String _describeRelation(BoundingBox box1, BoundingBox box2) {
    final centerX1 = (box1.left + box1.right) / 2;
    final centerY1 = (box1.top + box1.bottom) / 2;
    final centerX2 = (box2.left + box2.right) / 2;
    final centerY2 = (box2.top + box2.bottom) / 2;
    
    final xDiff = centerX2 - centerX1;
    final yDiff = centerY2 - centerY1;
    
    if (xDiff.abs() > yDiff.abs()) {
      // Horizontal relation is more significant
      if (xDiff > 0) {
        return 'to the right';
      } else {
        return 'to the left';
      }
    } else {
      // Vertical relation is more significant
      if (yDiff > 0) {
        return 'below';
      } else {
        return 'above';
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// ModelManager handles loading and management of different TFLite models
/// for advanced object detection and scene understanding
class ModelManager {
  // Available model types
  static const String EFFICIENTDET = 'efficientdet';
  static const String SSD_MOBILENET = 'ssd_mobilenet';
  
  // Currently loaded model
  static String _currentModel = EFFICIENTDET;
  static String get currentModel => _currentModel;
  
  // Model interpreters
  static Map<String, Interpreter> _interpreters = {};
  
  // Model labels
  static Map<String, List<String>> _labels = {};
  
  // Model configurations
  static final Map<String, ModelConfig> _modelConfigs = {
    EFFICIENTDET: ModelConfig(
      modelPath: 'assets/models/efficientdet/model.tflite',
      labelsPath: 'assets/models/efficientdet/labels.txt',
      inputSize: 300,
      outputShapes: {
        'locations': [1, 25, 4],       // Bounding box coordinates [top, left, bottom, right]
        'classes': [1, 25],            // Class indices
        'scores': [1, 25],             // Confidence scores
        'num_detections': [1],         // Number of detections
      },
      threshold: 0.5,
      numResults: 25,
      isQuantized: true,
    ),
    SSD_MOBILENET: ModelConfig(
      modelPath: 'assets/models/ssd_mobilenet/model.tflite',
      labelsPath: 'assets/models/ssd_mobilenet/labels.txt',
      inputSize: 300,
      outputShapes: {
        'locations': [1, 10, 4],       // Bounding box coordinates [top, left, bottom, right]
        'classes': [1, 10],            // Class indices
        'scores': [1, 10],             // Confidence scores
        'num_detections': [1],         // Number of detections
      },
      threshold: 0.5,
      numResults: 10,
      isQuantized: true,
    ),
  };
  
  /// Initialize the model manager by loading the default model
  static Future<void> initialize() async {
    await loadModel(EFFICIENTDET);
  }
  
  /// Load a specific model by its type identifier
  static Future<void> loadModel(String modelType) async {
    if (!_modelConfigs.containsKey(modelType)) {
      throw Exception('Unknown model type: $modelType');
    }
    
    try {
      // Close existing interpreter if switching models
      if (_interpreters.containsKey(_currentModel)) {
        _interpreters[_currentModel]?.close();
      }
      
      // Load the new model if not already loaded
      if (!_interpreters.containsKey(modelType)) {
        final config = _modelConfigs[modelType]!;
        
        // Set interpreter options
        final options = InterpreterOptions()
          ..threads = 4
          ..useNnApiForAndroid = true;  // Use Android Neural Networks API when available
        
        // Load interpreter
        _interpreters[modelType] = await Interpreter.fromAsset(
          config.modelPath,
          options: options,
        );
        
        // Load labels
        _labels[modelType] = await _loadLabels(config.labelsPath);
        
        debugPrint('Loaded model: $modelType');
        debugPrint('Input shape: ${_interpreters[modelType]?.getInputTensor(0).shape}');
        debugPrint('Output shape: ${_interpreters[modelType]?.getOutputTensor(0).shape}');
      }
      
      // Set as current model
      _currentModel = modelType;
    } catch (e) {
      debugPrint('Error loading model $modelType: $e');
      rethrow;
    }
  }
  
  /// Load labels from asset file
  static Future<List<String>> _loadLabels(String labelsPath) async {
    final rawLabels = await rootBundle.loadString(labelsPath);
    return rawLabels.split('\n');
  }
  
  /// Get the current model configuration
  static ModelConfig getModelConfig() {
    return _modelConfigs[_currentModel]!;
  }
  
  /// Get the interpreter for the current model
  static Interpreter? getInterpreter() {
    return _interpreters[_currentModel];
  }
  
  /// Get labels for the current model
  static List<String> getLabels() {
    return _labels[_currentModel] ?? [];
  }
  
  /// Clean up resources
  static void dispose() {
    for (final interpreter in _interpreters.values) {
      interpreter.close();
    }
    _interpreters.clear();
  }
  
  /// Switch to another model
  static Future<void> switchModel(String modelType) async {
    if (modelType != _currentModel) {
      await loadModel(modelType);
    }
  }
  
  /// Get label name from class index for the current model
  static String getLabelName(int classIndex) {
    final labels = _labels[_currentModel] ?? [];
    if (classIndex >= 0 && classIndex < labels.length) {
      final label = labels[classIndex];
      // Filter out placeholder labels (marked as ???)
      return label == '???' ? 'unknown' : label;
    }
    return 'unknown';
  }
  
  /// Generate a natural language description of the scene based on detected objects
  /// This is specifically designed to be helpful for blind users
  static String generateSceneDescription(List<DetectedObject> detections) {
    if (detections.isEmpty) {
      return 'No objects detected in view.';
    }
    
    // Group objects by category
    final Map<String, List<DetectedObject>> categorizedObjects = {};
    for (final detection in detections) {
      final category = detection.label;
      categorizedObjects.putIfAbsent(category, () => []).add(detection);
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
      
      if (centerX < 0.33) hasLeft = true;
      else if (centerX > 0.66) hasRight = true;
      else hasCenter = true;
      
      if (centerY < 0.33) hasTop = true;
      else if (centerY > 0.66) hasBottom = true;
      else hasMiddle = true;
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

/// Configuration for a TFLite model
class ModelConfig {
  final String modelPath;
  final String labelsPath;
  final int inputSize;
  final Map<String, List<int>> outputShapes;
  final double threshold;
  final int numResults;
  final bool isQuantized;
  
  ModelConfig({
    required this.modelPath,
    required this.labelsPath,
    required this.inputSize,
    required this.outputShapes,
    required this.threshold,
    required this.numResults,
    required this.isQuantized,
  });
}

/// Class to represent a detected object
class DetectedObject {
  final String label;
  final double confidence;
  final BoundingBox boundingBox;
  
  DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
  
  @override
  String toString() {
    return '$label (${(confidence * 100).toInt()}%)';
  }
}

/// Class to represent a bounding box
class BoundingBox {
  final double top;
  final double left;
  final double bottom;
  final double right;
  
  BoundingBox({
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
  });
  
  /// Get the width of the bounding box
  double get width => right - left;
  
  /// Get the height of the bounding box
  double get height => bottom - top;
  
  @override
  String toString() {
    return 'BoundingBox(top: $top, left: $left, bottom: $bottom, right: $right)';
  }
}

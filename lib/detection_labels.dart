import 'package:flutter/foundation.dart';

/// Class to parse and process TFLite object detection model outputs
class DetectionLabels {
  /// COCO dataset class labels (80 classes)
  /// These labels correspond to the class indices in many pre-trained models
  static const List<String> cocoLabels = [
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

  /// Get label name from class index
  /// Returns 'unknown' if the index is out of range
  static String getLabel(int classIndex) {
    if (classIndex >= 0 && classIndex < cocoLabels.length) {
      return cocoLabels[classIndex];
    }
    return 'unknown';
  }

  /// Parse raw detection results to a list of meaningful detection objects
  /// Filters out detections with confidence less than the threshold
  static List<TFDetectedObject> parseDetections(
    Map<String, dynamic> rawResult, {
    double confidenceThreshold = 0.5,
  }) {
    final List<TFDetectedObject> parsedDetections = [];
    
    // Check if there was an error in the detection
    if (rawResult.containsKey('error')) {
      debugPrint('Error in detection: ${rawResult['error']}');
      return parsedDetections;
    }
    
    // Get detections from the result
    final List<dynamic> detections = rawResult['detections'] as List<dynamic>;
    
    for (final detection in detections) {
      final score = detection['score'] as double;
      
      // Filter by confidence threshold
      if (score >= confidenceThreshold) {
        final classIndex = detection['class'] as int;
        final bbox = detection['bbox'] as Map<String, dynamic>;
        
        // Map index to label
        final label = getLabel(classIndex);
        
        // Create TFDetectedObject with all necessary information
        parsedDetections.add(
          TFDetectedObject(
            label: label,
            confidence: score,
            boundingBox: BoundingBox(
              top: bbox['top'] as double,
              left: bbox['left'] as double,
              bottom: bbox['bottom'] as double,
              right: bbox['right'] as double,
            ),
          ),
        );
      }
    }
    
    return parsedDetections;
  }
  
  /// Convert a list of detections to a readable string for TTS
  static String detectionsToString(List<TFDetectedObject> detections) {
    if (detections.isEmpty) {
      return 'No objects detected';
    }
    
    final buffer = StringBuffer();
    buffer.write('Detected ${detections.length} object${detections.length > 1 ? 's' : ''}: ');
    
    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final confidence = (detection.confidence * 100).toInt();
      
      buffer.write('${detection.label} ($confidence%)');
      
      if (i < detections.length - 1) {
        buffer.write(', ');
      }
    }
    
    return buffer.toString();
  }
}

/// Class to represent a TensorFlow Lite detected object
class TFDetectedObject {
  final String label;
  final double confidence;
  final BoundingBox boundingBox;
  
  TFDetectedObject({
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

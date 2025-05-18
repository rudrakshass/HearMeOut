import 'package:flutter/material.dart';
import 'efficientdet_service.dart';

class DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;
  final double confidenceThreshold;
  
  DetectionPainter({
    required this.detections,
    required this.imageSize,
    this.confidenceThreshold = 0.5,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Scale factor to convert from image coordinates to screen coordinates
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    
    for (final detection in detections) {
      if (detection.confidence < confidenceThreshold) continue;
      
      // Draw bounding box
      final rect = Rect.fromLTRB(
        detection.bbox.left * scaleX,
        detection.bbox.top * scaleY,
        detection.bbox.right * scaleX,
        detection.bbox.bottom * scaleY,
      );
      
      // Set color based on confidence
      final confidence = detection.confidence;
      paint.color = Color.fromRGBO(
        (255 * (1 - confidence)).toInt(),
        (255 * confidence).toInt(),
        0,
        1,
      );
      
      canvas.drawRect(rect, paint);
      
      // Draw label with confidence
      final label = '${detection.label} ${(detection.confidence * 100).toInt()}%';
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          backgroundColor: paint.color,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(rect.left, rect.top - textPainter.height),
      );
    }
  }
  
  @override
  bool shouldRepaint(DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections ||
           oldDelegate.imageSize != imageSize ||
           oldDelegate.confidenceThreshold != confidenceThreshold;
  }
} 
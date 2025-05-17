import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class FeedbackService {
  // Singleton pattern
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();
  
  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isBeepReady = false;
  
  // Control flags to prevent rapid consecutive feedback
  DateTime? _lastVibration;
  DateTime? _lastBeep;
  
  // Initialize the service
  Future<void> initialize() async {
    // Load beep sound
    try {
      await _audioPlayer.setSource(AssetSource('sounds/beep.mp3'));
      _isBeepReady = true;
      debugPrint('Beep sound loaded successfully');
    } catch (e) {
      debugPrint('Error loading beep sound: $e');
      _isBeepReady = false;
    }
  }
  
  // Trigger vibration when object is detected
  Future<void> vibrate({Duration? cooldown}) async {
    final now = DateTime.now();
    final cooldownPeriod = cooldown ?? const Duration(milliseconds: 1000);
    
    // Check if we should skip this vibration (cooldown period)
    if (_lastVibration != null && 
        now.difference(_lastVibration!) < cooldownPeriod) {
      return;
    }
    
    // Update last vibration timestamp
    _lastVibration = now;
    
    try {
      // Use built-in haptic feedback for object detection
      // First a medium impact followed by a light impact for a pattern effect
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error during haptic feedback: $e');
    }
  }
  
  // Play beep sound when object is centered
  Future<void> playBeep({Duration? cooldown}) async {
    if (!_isBeepReady) return;
    
    final now = DateTime.now();
    final cooldownPeriod = cooldown ?? const Duration(milliseconds: 1500);
    
    // Check if we should skip this beep (cooldown period)
    if (_lastBeep != null && 
        now.difference(_lastBeep!) < cooldownPeriod) {
      return;
    }
    
    // Update last beep timestamp
    _lastBeep = now;
    
    // Play beep sound
    try {
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Error playing beep sound: $e');
    }
  }
  
  // Check if the detected object is centered in the frame
  bool isObjectCentered(Rect objectBounds, Size screenSize, {double threshold = 0.15}) {
    // Calculate screen center
    final screenCenterX = screenSize.width / 2;
    final screenCenterY = screenSize.height / 2;
    
    // Calculate object center
    final objectCenterX = objectBounds.left + objectBounds.width / 2;
    final objectCenterY = objectBounds.top + objectBounds.height / 2;
    
    // Calculate allowable deviation in pixels based on screen dimensions
    final thresholdX = screenSize.width * threshold;
    final thresholdY = screenSize.height * threshold;
    
    // Calculate distance from object center to screen center
    final distanceX = (objectCenterX - screenCenterX).abs();
    final distanceY = (objectCenterY - screenCenterY).abs();
    
    // Check if object is within threshold from center
    return distanceX <= thresholdX && distanceY <= thresholdY;
  }
  
  // Process detected objects and provide appropriate feedback
  void processDetectedObjects(List<dynamic> detections, Size screenSize) {
    if (detections.isEmpty) return;
    
    // Always vibrate when objects are detected
    vibrate();
    
    // Check if any object is centered in the frame
    for (final detection in detections) {
      if (detection is Map<String, dynamic> && detection.containsKey('bbox')) {
        final bbox = detection['bbox'];
        if (bbox is Map<String, dynamic>) {
          final objectBounds = Rect.fromLTRB(
            (bbox['left'] as num).toDouble(),
            (bbox['top'] as num).toDouble(),
            (bbox['right'] as num).toDouble(),
            (bbox['bottom'] as num).toDouble(),
          );
          
          if (isObjectCentered(objectBounds, screenSize)) {
            playBeep();
            break;
          }
        }
      }
    }
  }
  
  // Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}

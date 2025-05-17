import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  static final TextToSpeechService _instance = TextToSpeechService._internal();
  factory TextToSpeechService() => _instance;
  TextToSpeechService._internal();
  
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  
  // Initialize TTS with preferred settings
  Future<void> initialize() async {
    // Set preferred language
    await _flutterTts.setLanguage("en-US");
    
    // Set speech rate (0.0 to 1.0, default is 0.5)
    await _flutterTts.setSpeechRate(0.5);
    
    // Set volume (0.0 to 1.0, default is 1.0)
    await _flutterTts.setVolume(1.0);
    
    // Set pitch (0.0 to 2.0, default is 1.0)
    await _flutterTts.setPitch(1.0);
    
    // Handle completion event
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    // Handle error event
    _flutterTts.setErrorHandler((error) {
      debugPrint("TTS Error: $error");
      _isSpeaking = false;
    });
  }
  
  // Speak a list of detected objects
  Future<void> speakDetectedObjects(List<String> objectLabels) async {
    if (objectLabels.isEmpty) {
      await speak("No objects detected");
      return;
    }
    
    // Create a sentence with commas
    final String sentence = _formatObjectsToSentence(objectLabels);
    
    // Speak the sentence
    await speak(sentence);
  }
  
  // Format objects into a readable sentence
  String _formatObjectsToSentence(List<String> objectLabels) {
    if (objectLabels.isEmpty) return "No objects detected";
    
    if (objectLabels.length == 1) return "Detected a ${objectLabels[0]}";
    
    final buffer = StringBuffer();
    buffer.write("Detected ");
    
    if (objectLabels.length == 2) {
      buffer.write("${objectLabels[0]} and ${objectLabels[1]}");
    } else {
      for (int i = 0; i < objectLabels.length; i++) {
        if (i == objectLabels.length - 1) {
          buffer.write("and ${objectLabels[i]}");
        } else {
          buffer.write("${objectLabels[i]}, ");
        }
      }
    }
    
    return buffer.toString();
  }
  
  // General speak method
  Future<void> speak(String text) async {
    if (_isSpeaking) {
      await stop();
    }
    
    _isSpeaking = true;
    await _flutterTts.speak(text);
  }
  
  // Stop speaking
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }
  
  // Check if TTS is speaking
  bool get isSpeaking => _isSpeaking;
  
  // Clean up resources
  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}

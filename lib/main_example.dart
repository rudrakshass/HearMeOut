import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

// Import our services
import 'tflite_service.dart';
import 'text_to_speech_service.dart';
import 'feedback_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Request camera permissions
  await Permission.camera.request();
  
  // Get available cameras
  final cameras = await availableCameras();
  if (cameras.isEmpty) {
    print('No cameras available');
    return;
  }
  
  // Initialize TFLite model with enhanced detection for blind users
  await TFLiteService.initialize(modelType: 'efficientdet');
  
  // Run the app
  runApp(VisionApp(cameras: cameras));
}

class VisionApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  
  const VisionApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: CameraScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  
  // Service instances
  final TextToSpeechService _tts = TextToSpeechService();
  final FeedbackService _feedbackService = FeedbackService();
  
  // Detection results
  String _detectionResults = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeCamera();
  }
  
  Future<void> _initializeServices() async {
    await _tts.initialize();
    await _feedbackService.initialize();
  }
  
  Future<void> _initializeCamera() async {
    // Initialize with the first available camera (usually back camera)
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    
    try {
      await _controller.initialize();
      
      // Set optimal focus mode for object detection
      await _controller.setFocusMode(FocusMode.auto);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _tts.dispose();
    _feedbackService.dispose();
    super.dispose();
  }
  
  Future<void> _captureAndProcess() async {
    if (!_isInitialized || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Lock focus for better image quality
      await _controller.setFocusMode(FocusMode.locked);
      
      // Capture current frame from camera
      final XFile imageFile = await _controller.takePicture();
      
      // Process the image
      await _processImage(imageFile);
      
      // Reset focus mode for preview
      await _controller.setFocusMode(FocusMode.auto);
    } catch (e) {
      print('Error capturing image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  Future<void> _processImage(XFile imageFile) async {
    // Create input for TFLite inference
    final File file = File(imageFile.path);
    
    try {
      // Run object detection
      final result = await _processObjectDetection(file);
      
      // Update UI with results
      if (mounted) {
        setState(() {
          _detectionResults = result['description'] as String;
        });
      }
      
      // Speak detected objects
      if (result['speak'] != null) {
        await _tts.speak(result['speak'] as String);
      }
      
      // Provide haptic feedback for detections
      if (result['detected']) {
        await _feedbackService.vibrate();
        
        // If any object is centered, play beep
        if (result['hasObjectCentered'] == true) {
          await _feedbackService.playBeep();
        }
      }
    } catch (e) {
      print('Error processing image: $e');
    }
  }
  
  Future<Map<String, dynamic>> _processObjectDetection(File imageFile) async {
    // This is a simplified version. In a real app, you would:
    // 1. Convert the image to the format expected by TFLite
    // 2. Run inference with TFLiteService
    // 3. Parse the results
    
    try {
      // In our actual implementation, we use TFLiteService to detect objects
      // For this example, we'll simulate detection results
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate processing time
      
      // Get the screen size for determining if objects are centered
      final screenSize = MediaQuery.of(context).size;
      
      // Simulate detection of 2 objects
      final List<Map<String, dynamic>> detections = [
        {
          'label': 'Person',
          'confidence': 0.92,
          'bbox': Rect.fromLTRB(
            screenSize.width * 0.3,
            screenSize.height * 0.2,
            screenSize.width * 0.7,
            screenSize.height * 0.8
          ),
        },
        {
          'label': 'Cup',
          'confidence': 0.85,
          'bbox': Rect.fromLTRB(
            screenSize.width * 0.1,
            screenSize.height * 0.1,
            screenSize.width * 0.3,
            screenSize.height * 0.3
          ),
        }
      ];
      
      // Check if any object is centered
      bool hasObjectCentered = false;
      for (final detection in detections) {
        if (_feedbackService.isObjectCentered(
          detection['bbox'] as Rect,
          screenSize
        )) {
          hasObjectCentered = true;
          break;
        }
      }
      
      // Create detection summary for TTS
      final String ttsDescription = "I detected 2 objects: a Person in the center and a Cup on the left at the top";
      
      return {
        'detected': true,
        'detections': detections,
        'description': 'Detected: Person (92%), Cup (85%)',
        'speak': ttsDescription,
        'hasObjectCentered': hasObjectCentered,
      };
    } catch (e) {
      print('Error in object detection: $e');
      return {
        'detected': false,
        'description': 'Error: $e',
        'speak': 'Error processing image',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision App'),
        backgroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          // Camera preview
          GestureDetector(
            onTap: _captureAndProcess,
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.previewSize!.height,
                  height: _controller.value.previewSize!.width,
                  child: CameraPreview(_controller),
                ),
              ),
            ),
          ),
          
          // Instructions overlay
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tap to analyze',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          
          // Results overlay
          if (_detectionResults.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _detectionResults,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          
          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

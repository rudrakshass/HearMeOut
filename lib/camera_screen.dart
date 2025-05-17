import 'package:flutter/material.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> cameras = [];
  bool _isInitialized = false;
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }
  
  // Request required permissions
  Future<void> _requestPermissions() async {
    // Request camera permission
    final status = await Permission.camera.request();
    
    if (status.isGranted) {
      // If permission granted, initialize camera
      _initializeCamera();
    } else if (status.isDenied) {
      // If permission denied, show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to use this app'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        return;
      }
      
      // Initialize controller with the first (back) camera
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Initialize the controller
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // Function to recognize text in an image
  Future<String> _processImageForText(String imagePath) async {
    final InputImage inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    
    String text = recognizedText.text;
    
    // Log detailed block information
    for (TextBlock block in recognizedText.blocks) {
      debugPrint('Block: ${block.text}');
      for (TextLine line in block.lines) {
        debugPrint('Line: ${line.text}');
      }
    }
    
    return text.isEmpty ? 'No text detected' : text;
  }
  
  // Function to show recognized text in a dialog
  void _showRecognizedTextDialog(String text) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recognized Text'),
        content: SingleChildScrollView(
          child: Text(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Function to capture an image and process it
  Future<void> _captureImage() async {
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      // Take the picture
      final XFile image = await _controller!.takePicture();
      
      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      
      // Create a destination path
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = path.join(tempDir.path, 'image_$timestamp.jpg');
      
      // Copy the image to our new path
      await File(image.path).copy(filePath);
      
      if (mounted) {
        // Show a snackbar with the image path
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved to: $filePath'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      debugPrint('Image saved at: $filePath');
      
      // Process the image for text recognition
      debugPrint('Starting text recognition...');
      final String recognizedText = await _processImageForText(filePath);
      debugPrint('Recognized text: $recognizedText');
      
      // Show the recognized text in a dialog
      if (mounted) {
        _showRecognizedTextDialog(recognizedText);
      }
      
    } catch (e) {
      debugPrint('Error capturing or processing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      // Return a loading indicator if the camera is still initializing
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _requestPermissions,
                child: const Text('Grant Camera Permission'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Calculate the screen aspect ratio
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview that fills the screen
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height * deviceRatio,
                height: _controller!.value.previewSize!.height,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
        ],
      ),
      // Floating capture button at the bottom
      floatingActionButton: FloatingActionButton(
        onPressed: _captureImage,
        backgroundColor: Colors.white,
        child: const Icon(Icons.camera_alt, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> cameras = [];
  bool _isInitialized = false;
  bool _isProcessing = false;
  
  // Use script-specific text recognizer for better accuracy
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

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
      
      // Initialize controller with the first (back) camera with maximum resolution
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.veryHigh, // Higher resolution for better text recognition
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false, // Audio not needed for OCR
      );

      // Initialize the controller
      await _controller!.initialize();
      
      // Set optimal focus mode for text recognition
      await _controller!.setFocusMode(FocusMode.auto);
      
      // Set flash mode off initially
      await _controller!.setFlashMode(FlashMode.off);
      
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

  // Function to enhance image before processing
  Future<File> _enhanceImageForOCR(String imagePath) async {
    // This is a placeholder for image enhancement
    // In a full implementation, you could use image processing libraries to:  
    // - Increase contrast
    // - Apply sharpening
    // - Convert to grayscale
    // - Apply thresholding
    // - Fix rotation and perspective
    
    // For now, we just return the original file
    return File(imagePath);
  }

  // Function to recognize text in an image with improved accuracy
  Future<String> _processImageForText(String imagePath) async {
    try {
      // Enhance the image for better OCR results
      final File enhancedImage = await _enhanceImageForOCR(imagePath);
      
      // Create input image from file
      final InputImage inputImage = InputImage.fromFilePath(enhancedImage.path);
      
      // Process the image with the text recognizer
      // The Latin script recognizer is optimized for Latin-based languages
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      String text = recognizedText.text;
      
      // Log detailed block information for debugging
      for (TextBlock block in recognizedText.blocks) {
        debugPrint('Block: ${block.text}');
        // Log bounding box information
        debugPrint('Block bounds: ${block.boundingBox}');
        
        for (TextLine line in block.lines) {
          debugPrint('Line: ${line.text}');
          
          // Log individual elements for debugging
          for (TextElement element in line.elements) {
            debugPrint('  Element: "${element.text}" (${element.boundingBox})');
          }
        }
      }
      
      // Filter out very short detected text (likely noise)
      if (text.trim().length < 2) {
        return 'No meaningful text detected';
      }
      
      return text.isEmpty ? 'No text detected' : text;
    } catch (e) {
      debugPrint('Error during text recognition: $e');
      return 'Error during text recognition: $e';
    }
  }
  
  // Function to show recognized text in a dialog with improved UI
  void _showRecognizedTextDialog(String text) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recognized Text'),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  text,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copy text to clipboard
              _copyToClipboard(text);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  // Copy text to clipboard and show confirmation
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Function to capture an image and process it
  Future<void> _captureImage() async {
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true; // Set processing flag to prevent multiple captures
    });

    try {
      // Set optimal focus mode for taking picture
      await _controller!.setFocusMode(FocusMode.locked);
      
      // Add a small delay for camera to fully stabilize focus (improves clarity)
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Take the picture with increased quality
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
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      debugPrint('Image saved at: $filePath');
      
      // Process the image for text recognition
      debugPrint('Starting text recognition...');
      
      // Show a processing indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing image for text...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      final String recognizedText = await _processImageForText(filePath);
      debugPrint('Recognized text: $recognizedText');
      
      // Show the recognized text in a dialog
      if (mounted) {
        _showRecognizedTextDialog(recognizedText);
      }
      
      // Reset focus mode back to auto for preview
      await _controller!.setFocusMode(FocusMode.auto);
      
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
    } finally {
      // Reset processing flag
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      // Return a loading indicator if the camera is still initializing
      return Scaffold(
        appBar: AppBar(
          title: const Text('Vision App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Camera initializing or permission required'),
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
          
          // Semi-transparent overlay with instructions
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.black54,
              child: const Text(
                'Position text in frame and tap the button to capture',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      // Floating capture button at the bottom
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Primary capture button
          FloatingActionButton(
            onPressed: _isProcessing ? null : _captureImage,
            backgroundColor: _isProcessing ? Colors.grey : Colors.white,
            child: _isProcessing 
              ? const SizedBox(
                  width: 24, 
                  height: 24, 
                  child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.black)
                )
              : const Icon(Icons.camera_alt, color: Colors.black),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

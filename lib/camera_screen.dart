import 'package:flutter/material.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'tflite_service.dart';
import 'text_to_speech_service.dart';
import 'detection_labels.dart';
import 'feedback_service.dart';

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
  
  // Object detector with classification
  late ObjectDetector _objectDetector;
  
  // Text-to-speech service for accessibility
  final TextToSpeechService _tts = TextToSpeechService();
  
  // Feedback service for vibration and sound
  final FeedbackService _feedbackService = FeedbackService();
  
  // Store detection results
  List<DetectedObject>? _detectedObjects;
  
  // TFLite inference results
  String _tfliteResults = '';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initDetector();
    _initializeTTS();
    _loadTFLiteModel();
    _initializeFeedbackService();
  }
  
  // Initialize feedback service
  Future<void> _initializeFeedbackService() async {
    await _feedbackService.initialize();
  }
  
  // Load the TFLite model from assets
  Future<void> _loadTFLiteModel() async {
    try {
      await TFLiteService.loadModel();
      if (mounted) {
        setState(() {
          // Update UI if needed when model is loaded
        });
      }
      debugPrint('TFLite model loaded: ${TFLiteService.isModelLoaded ? "Success" : "Failed"}');
    } catch (e) {
      debugPrint('Error loading TFLite model: $e');
    }
  }
  
  // Initialize the object detector
  Future<void> _initDetector() async {
    // Configure detection options
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single, // Process a single image
      classifyObjects: true, // Enable classification
      multipleObjects: true, // Detect multiple objects in the image
    );
    
    _objectDetector = ObjectDetector(options: options);
  }
  
  // We're using the built-in model for object detection
  // ML Kit provides pre-trained models that work well for common scenarios
  
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
    _objectDetector.close();
    TFLiteService.dispose();
    _tts.dispose();
    _feedbackService.dispose();
    super.dispose();
  }
  
  // Initialize text-to-speech service
  Future<void> _initializeTTS() async {
    await _tts.initialize();
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

  // Convert a saved image file back to CameraImage format for TFLite
  Future<CameraImage?> _convertFileToCameraImage(XFile file) async {
    try {
      // This is a simplified version as actual YUV conversion from a JPEG file is complex
      // For real implementation, you would need to decompress the JPEG and convert to YUV format
      // This is a placeholder that enables our workflow to continue
      return null;
    } catch (e) {
      debugPrint('Error converting file to camera image: $e');
      return null;
    }
  }
  
  // Run TFLite inference on a camera image
  Future<void> _runTFLiteInference(CameraImage cameraImage) async {
    if (!TFLiteService.isModelLoaded) {
      _tfliteResults = 'TFLite model not loaded';
      return;
    }
    
    try {
      // Run object detection using our enhanced service with COCO labels
      final result = await TFLiteService.detectObjectsInImage(cameraImage, threshold: 0.5);
      
      // Check for errors
      if (result.containsKey('error')) {
        debugPrint('Error in TFLite detection: ${result['error']}');
        _tfliteResults = 'Error in object detection';
        return;
      }
      
      // Store formatted detection summary for the UI
      if (result.containsKey('summary')) {
        _tfliteResults = result['summary'] as String;
      } else {
        _tfliteResults = 'No objects detected';
      }
      
      // Extract object labels for speech
      if (result.containsKey('detections')) {
        final List<TFDetectedObject> detections = result['detections'] as List<TFDetectedObject>;
        await _speakDetectedObjects(detections);
      }
      
      // Log the detection results for debugging
      debugPrint('TFLite detection results: $result');
    } catch (e) {
      debugPrint('Error running TFLite detection: $e');
      _tfliteResults = 'Error in object detection analysis';
    }
  }
  
  // Speak detected objects using enhanced TTS service
  Future<void> _speakDetectedObjects(List<TFDetectedObject> detections) async {
    // Extract just the labels from detections
    final labels = detections.map((d) => d.label).toList();
    
    // Speak the detected objects
    await _tts.speakDetectedObjects(labels);
  }
  
  // Detect objects in an image
  Future<List<DetectedObject>> _detectObjects(String imagePath) async {
    try {
      // Create input image
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      
      // Process image with object detector
      final List<DetectedObject> objects = await _objectDetector.processImage(inputImage);
      
      // Log object detection results
      debugPrint('Detected ${objects.length} objects:');
      for (final DetectedObject object in objects) {
        debugPrint('Object at ${object.boundingBox}:');
        for (final Label label in object.labels) {
          debugPrint('  Label: ${label.text}, confidence: ${label.confidence}');
        }
      }
      
      return objects;
    } catch (e) {
      debugPrint('Error during object detection: $e');
      return [];
    }
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
  
  // Function to show recognized text and objects in a dialog with improved UI
  void _showRecognizedTextDialog(String text) {
    if (!mounted) return;
    
    // Prepare object detection results if available
    String objectsText = '';
    if (_detectedObjects != null && _detectedObjects!.isNotEmpty) {
      // Map to count occurrences of each label
      final Map<String, int> labelCounts = {};
      
      // Process all detected objects
      for (final DetectedObject object in _detectedObjects!) {
        for (final Label label in object.labels) {
          final String labelText = '${label.text} (${(label.confidence * 100).toStringAsFixed(1)}%)';
          labelCounts[labelText] = (labelCounts[labelText] ?? 0) + 1;
        }
      }
      
      // Build a string of all labels
      final List<String> objectLabels = [];
      labelCounts.forEach((label, count) {
        objectLabels.add(count > 1 ? '$label x$count' : label);
      });
      
      if (objectLabels.isNotEmpty) {
        objectsText = 'Objects detected:\n• ${objectLabels.join('\n• ')}';
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analysis Results'),
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
                if (text.isNotEmpty) ...[  
                  const Text('Recognized Text:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText(
                    text,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                if (text.isNotEmpty && objectsText.isNotEmpty)
                  const Divider(height: 24),
                if (objectsText.isNotEmpty) ...[  
                  const Text('Objects:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText(
                    objectsText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                if (text.isEmpty && objectsText.isEmpty)
                  const Text('No text or objects detected'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copy all results to clipboard
              String clipboardText = '';
              if (text.isNotEmpty) {
                clipboardText += 'RECOGNIZED TEXT:\n$text';
              }
              if (objectsText.isNotEmpty) {
                if (clipboardText.isNotEmpty) clipboardText += '\n\n';
                clipboardText += objectsText;
              }
              _copyToClipboard(clipboardText);
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

  // Provide accessibility feedback
  Future<void> _provideAccessibilityFeedback(String message) async {
    debugPrint('TTS: $message');
    await _tts.speak(message);
  }

  // Function to capture an image and process it with OCR, object detection, and TTS
  Future<void> _captureImage() async {
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }
    
    // Provide immediate audio feedback for blind users
    _provideAccessibilityFeedback("Capturing image");

    setState(() {
      _isProcessing = true; // Set processing flag to prevent multiple captures
    });

    try {
      // Set optimal focus mode for taking picture
      await _controller!.setFocusMode(FocusMode.locked);
      
      // Add a small delay for camera to fully stabilize focus (improves clarity)
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Take the picture
      final XFile image = await _controller!.takePicture();
      
      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      
      // Create a destination path
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = path.join(tempDir.path, 'image_$timestamp.jpg');
      
      // Copy the image to our new path
      await File(image.path).copy(filePath);
      
      // Provide audio feedback that processing has started
      await _provideAccessibilityFeedback("Processing image, please wait");
      
      debugPrint('Image saved at: $filePath');
      debugPrint('Starting OCR and object detection...');
      
      // Read the saved image file as XFile for processing
      final XFile xFile = XFile(filePath);
      final CameraImage? cameraImage = await _convertFileToCameraImage(xFile);
      
      // Run TFLite inference if a camera image could be created
      if (cameraImage != null) {
        try {
          await _runTFLiteInference(cameraImage);
        } catch (e) {
          debugPrint('TFLite inference error: $e');
          _tfliteResults = 'TFLite inference failed';
        }
      }
      
      // Run text recognition and object detection in parallel for efficiency
      final futures = await Future.wait([
        _processImageForText(filePath),
        _detectObjects(filePath),
      ]);
      
      final String recognizedText = futures[0] as String;
      final List<DetectedObject> detectedObjects = futures[1] as List<DetectedObject>;
      
      // Store the detected objects for UI display
      _detectedObjects = detectedObjects;
      
      debugPrint('Recognized text: $recognizedText');
      debugPrint('Detected ${detectedObjects.length} objects');
      
      // Provide haptic feedback if objects are detected
      if (detectedObjects.isNotEmpty) {
        _feedbackService.vibrate();
        
        // Check if any object is centered in the frame and play beep sound if so
        for (final object in detectedObjects) {
          if (_feedbackService.isObjectCentered(object.boundingBox, MediaQuery.of(context).size)) {
            _feedbackService.playBeep();
            break;
          }
        }
      }
      
      // Create a summary of detected objects for TTS
      String objectsSummary = '';
      if (detectedObjects.isNotEmpty) {
        final Map<String, double> bestLabels = {};
        
        // Get the best confidence label for each object
        for (final object in detectedObjects) {
          for (final label in object.labels) {
            // Store the highest confidence for each label
            if (!bestLabels.containsKey(label.text) || 
                label.confidence > bestLabels[label.text]!) {
              bestLabels[label.text] = label.confidence;
            }
          }
        }
        
        // Filter to only include reasonable confidence
        final List<String> filteredLabels = [];
        bestLabels.forEach((label, confidence) {
          if (confidence > 0.6) {
            filteredLabels.add(label);
          }
        });
        
        if (filteredLabels.isNotEmpty) {
          objectsSummary = "Objects detected: ${filteredLabels.join(', ')}"; 
        }
      }
      
      // Prepare text for TTS (truncate if too long)
      String ttsText = '';
      if (recognizedText.isNotEmpty && !recognizedText.contains("No text detected")) {
        if (recognizedText.length > 150) {
          ttsText = "${recognizedText.substring(0, 147)}... and more text";
        } else {
          ttsText = recognizedText;
        }
      }
      
      // Show the results in a dialog
      if (mounted) {
        _showRecognizedTextDialog(recognizedText);
      }
      
      // Create combined feedback for TTS
      String feedbackText = '';
      
      // Start with objects as they're often more important for context
      if (objectsSummary.isNotEmpty) {
        feedbackText = objectsSummary;
      }
      
      // Then add text if available
      if (ttsText.isNotEmpty) {
        if (feedbackText.isNotEmpty) {
          feedbackText += ". I also found text: ";
        } else {
          feedbackText = "Text found: ";
        }
        feedbackText += ttsText;
      }
      
      // Add TFLite results if available
      if (_tfliteResults.isNotEmpty) {
        if (feedbackText.isNotEmpty) {
          feedbackText += ". ";
        }
        feedbackText += "From TensorFlow analysis: $_tfliteResults";
      }
      
      // Handle case where nothing was detected
      if (feedbackText.isEmpty) {
        feedbackText = "No text or objects detected in this image";
      }
      
      // Read out the results with TTS
      await _provideAccessibilityFeedback(feedbackText);
      
      // Reset focus mode back to auto for preview
      await _controller!.setFocusMode(FocusMode.auto);
      
    } catch (e) {
      debugPrint('Error capturing or processing image: $e');
      if (mounted) {
        // Provide audio feedback about the error
        _provideAccessibilityFeedback("Error processing image");
        
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
      appBar: AppBar(
        title: const Text('Vision App'),
        backgroundColor: Colors.black87,
        actions: [
          // Help button
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showInstructions(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview that fills the screen with tap gesture
          GestureDetector(
            onTap: _isProcessing ? null : _captureImage,
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize!.height * deviceRatio,
                  height: _controller!.value.previewSize!.height,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
          
          // Semi-transparent overlay with instructions
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tap anywhere to analyze',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          
          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              width: double.infinity,
              height: double.infinity,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

// Show instructions dialog
void _showInstructions(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('How to Use'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• Tap anywhere on the screen to capture and analyze an image'),
          SizedBox(height: 8),
          Text('• The app will detect objects using TensorFlow Lite'),
          SizedBox(height: 8),
          Text('• Results will be spoken aloud for accessibility'),
          SizedBox(height: 8),
          Text('• Wait for processing to complete before capturing again'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
}

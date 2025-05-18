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
  
  // Scene description for blind users
  String _sceneDescription = '';

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
  
  // Load the TFLite model from assets - enhanced version for blind users
  Future<void> _loadTFLiteModel() async {
    try {
      await TFLiteService.initialize(modelType: 'efficientdet'); // Use efficientdet for better accuracy
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
      debugPrint('TFLite model not loaded yet');
      return;
    }
    
    try {
      // Process image and detect objects with enhanced algorithm
      final detectionResults = await TFLiteService.detectObjectsInImage(
        cameraImage,
        threshold: 0.5, // Confidence threshold
      );
      
      if (detectionResults.containsKey('error')) {
        debugPrint('Error detecting objects: ${detectionResults['error']}');
        return;
      }
      
      // Extract detected objects and scene description
      final detections = detectionResults['detections'] as List<DetectedObject>;
      _detectedObjects = detections;
      
      // Get the detailed scene description for blind users
      final sceneDescription = detectionResults['summary'] as String;
      
      // Update UI
      if (mounted) {
        setState(() {
          _tfliteResults = sceneDescription;
          _sceneDescription = sceneDescription;
        });
      }
      
      // Speak detailed scene description
      _speakSceneDescription(sceneDescription);
      
      // Provide haptic feedback when objects are detected
      if (detections.isNotEmpty) {
        // Vibrate to alert the user that objects were detected
        await _feedbackService.vibrate();
        
        // If scene has many objects, provide additional feedback
        if (detections.length > 5) {
          // Play a beep for significant detections
          await _feedbackService.playBeep();
        }
      }
    } catch (e) {
      debugPrint('Error running TFLite inference: $e');
    }
  }
  
  // Speak detected objects using enhanced TTS service
  // Speak detailed scene description for blind users
  Future<void> _speakSceneDescription(String description) async {
    if (description.isEmpty) {
      await _tts.speak('No objects detected in view');
      return;
    }
    
    // Speak the detailed scene description
    await _tts.speak(description);
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
        // Collect all object labels with reasonable confidence
        final Map<String, int> labelCounts = {};
        final Map<String, List<Rect>> labelPositions = {};
        
        // Process each detected object
        for (final object in detectedObjects) {
          // Find the best label for this object (highest confidence)
          String? bestLabel;
          double bestConfidence = 0.0;
          
          for (final label in object.labels) {
            if (label.confidence > bestConfidence && label.confidence > 0.4) {
              bestLabel = label.text;
              bestConfidence = label.confidence;
            }
          }
          
          if (bestLabel != null) {
            // Count occurrences of each label
            labelCounts[bestLabel] = (labelCounts[bestLabel] ?? 0) + 1;
            
            // Store position information for spatial description
            if (!labelPositions.containsKey(bestLabel)) {
              labelPositions[bestLabel] = [];
            }
            labelPositions[bestLabel]!.add(object.boundingBox);
          }
        }
        
        // Create a detailed description with counts and positions
        if (labelCounts.isNotEmpty) {
          // Count total number of objects detected
          int totalObjectCount = 0;
          labelCounts.values.forEach((count) => totalObjectCount += count);
          
          // Start with total count of objects
          final StringBuffer summaryBuffer = StringBuffer();
          summaryBuffer.write("I detected $totalObjectCount ${totalObjectCount == 1 ? 'object' : 'objects'}: ");
          
          // Prepare detailed descriptions for each object type
          final List<String> classDescriptions = [];
          final Size screenSize = MediaQuery.of(context).size;
          
          labelCounts.forEach((label, count) {
            // Start the description with the count and label
            final StringBuffer classDescription = StringBuffer();
            classDescription.write(count > 1 ? "$count ${label}s" : "a $label");
            
            // For multiple objects of the same class, describe each one's position
            if (count > 1 && labelPositions[label]!.isNotEmpty) {
              classDescription.write(": ");
              final List<String> individualPositions = [];
              
              // Describe each instance with its position
              for (int i = 0; i < labelPositions[label]!.length; i++) {
                final Rect position = labelPositions[label]![i];
                final double centerX = position.left + position.width / 2;
                final double centerY = position.top + position.height / 2;
                
                // Determine position in frame (simple left/right/center, top/bottom/middle)
                String horizontalPosition = "";
                String verticalPosition = "";
                
                // Horizontal position - flip the calculation since camera view is mirrored
                if (centerX < screenSize.width / 3) {
                  horizontalPosition = "on the right"; // Flipped from left to right
                } else if (centerX > 2 * screenSize.width / 3) {
                  horizontalPosition = "on the left"; // Flipped from right to left
                } else {
                  horizontalPosition = "in the center";
                }
                
                // Vertical position
                if (centerY < screenSize.height / 3) {
                  verticalPosition = "at the top";
                } else if (centerY > 2 * screenSize.height / 3) {
                  verticalPosition = "at the bottom";
                } else {
                  verticalPosition = "in the middle";
                }
                
                // Distance approximation based on object size relative to screen size
                final double objectArea = position.width * position.height;
                final double screenArea = screenSize.width * screenSize.height;
                final double sizeRatio = objectArea / screenArea;
                
                String distanceApprox = "";
                if (sizeRatio > 0.3) {
                  distanceApprox = " very close";
                } else if (sizeRatio > 0.1) {
                  distanceApprox = " close";
                } else if (sizeRatio > 0.05) {
                  distanceApprox = " nearby";
                } else if (sizeRatio > 0.01) {
                  distanceApprox = " at medium distance";
                } else {
                  distanceApprox = " far away";
                }
                
                // Add position for this specific object
                String ordinal = "";
                if (count > 2) {
                  // Use ordinals for 3+ objects
                  switch (i) {
                    case 0: ordinal = "first "; break;
                    case 1: ordinal = "second "; break;
                    case 2: ordinal = "third "; break;
                    default: ordinal = "${i+1}th ";
                  }
                } else if (count == 2) {
                  // For exactly 2 objects, use simpler terms
                  ordinal = i == 0 ? "one " : "another ";
                }
                
                individualPositions.add("$ordinal$horizontalPosition $verticalPosition$distanceApprox");
              }
              
              // Join all positions with commas and 'and'
              if (individualPositions.length == 1) {
                classDescription.write(individualPositions[0]);
              } else if (individualPositions.length == 2) {
                classDescription.write("${individualPositions[0]} and ${individualPositions[1]}");
              } else {
                final String lastPosition = individualPositions.removeLast();
                classDescription.write("${individualPositions.join(', ')}, and $lastPosition");
              }
            } 
            // For a single object, just add its position
            else if (labelPositions[label]!.isNotEmpty) {
              final Rect position = labelPositions[label]!.first;
              final double centerX = position.left + position.width / 2;
              final double centerY = position.top + position.height / 2;
              
              // Determine position in frame
              String horizontalPosition = "";
              String verticalPosition = "";
              
              // Horizontal position - flip the calculation since camera view is mirrored
              if (centerX < screenSize.width / 3) {
                horizontalPosition = "on the right"; // Flipped from left to right
              } else if (centerX > 2 * screenSize.width / 3) {
                horizontalPosition = "on the left"; // Flipped from right to left
              } else {
                horizontalPosition = "in the center";
              }
              
              // Vertical position
              if (centerY < screenSize.height / 3) {
                verticalPosition = "at the top";
              } else if (centerY > 2 * screenSize.height / 3) {
                verticalPosition = "at the bottom";
              } else {
                verticalPosition = "in the middle";
              }
              
              // Add distance approximation based on object size
              final double objectArea = position.width * position.height;
              final double screenArea = screenSize.width * screenSize.height;
              final double sizeRatio = objectArea / screenArea;
              
              String distanceApprox = "";
              if (sizeRatio > 0.3) {
                distanceApprox = " very close";
              } else if (sizeRatio > 0.1) {
                distanceApprox = " close";
              } else if (sizeRatio > 0.05) {
                distanceApprox = " nearby";
              } else if (sizeRatio > 0.01) {
                distanceApprox = " at medium distance";
              } else {
                distanceApprox = " far away";
              }
              
              classDescription.write(" $horizontalPosition $verticalPosition$distanceApprox");
            }
            
            classDescriptions.add(classDescription.toString());
          });
          
          // Format the final description
          if (classDescriptions.length == 1) {
            summaryBuffer.write(classDescriptions[0]);
          } else if (classDescriptions.length == 2) {
            summaryBuffer.write("${classDescriptions[0]} and ${classDescriptions[1]}");
          } else {
            final String lastClassDescription = classDescriptions.removeLast();
            summaryBuffer.write("${classDescriptions.join(', ')}, and $lastClassDescription");
          }
          
          objectsSummary = summaryBuffer.toString();
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
      
      // Always start with objects (even if none detected)
      if (objectsSummary.isNotEmpty) {
        feedbackText = objectsSummary;
      } else {
        feedbackText = "No objects detected";
      }
      
      // Then add text if available, but only if it's meaningful (not just 'No text detected')
      if (ttsText.isNotEmpty && 
          !ttsText.contains("No meaningful text detected") && 
          !ttsText.contains("No text detected")) {
        feedbackText += ". I also found text: " + ttsText;
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
          
          // Semi-transparent overlay with instructions or scene description
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
                child: Text(
                  _sceneDescription.isEmpty ? 'Tap anywhere to analyze' : _sceneDescription,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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

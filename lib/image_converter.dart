import 'dart:typed_data';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as imglib;

class ImageConverter {
  /// Converts a CameraImage in YUV420 format to RGB format
  /// Returns an image usable for TFLite inference
  static Uint8List convertYUV420toRGB(CameraImage cameraImage, {int? targetWidth, int? targetHeight}) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    // Get the Y, U, and V planes from the camera image
    final yPlane = cameraImage.planes[0].bytes;
    final uPlane = cameraImage.planes[1].bytes;
    final vPlane = cameraImage.planes[2].bytes;
    
    // Get the row strides for each plane
    final yRowStride = cameraImage.planes[0].bytesPerRow;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;
    
    // Create an empty image buffer (RGB)
    final rgbBytes = Uint8List(width * height * 3);
    
    // Convert YUV to RGB
    int rgbIndex = 0;
    for (int y = 0; y < height; y++) {
      int yIndex = y * yRowStride;
      int uvIndex = (y ~/ 2) * uvRowStride;
      
      for (int x = 0; x < width; x++) {
        final int uvx = (x ~/ 2) * uvPixelStride;
        
        // Get YUV values
        final yValue = yPlane[yIndex + x] & 0xff;
        final uValue = uPlane[uvIndex + uvx] & 0xff;
        final vValue = vPlane[uvIndex + uvx] & 0xff;
        
        // Convert YUV to RGB using formula
        // R = Y + 1.402 * (V - 128)
        // G = Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)
        // B = Y + 1.772 * (U - 128)
        int r = yValue + (1.402 * (vValue - 128)).toInt();
        int g = yValue - (0.344136 * (uValue - 128)).toInt() - (0.714136 * (vValue - 128)).toInt();
        int b = yValue + (1.772 * (uValue - 128)).toInt();
        
        // Clamp RGB values to [0, 255]
        r = max(0, min(255, r));
        g = max(0, min(255, g));
        b = max(0, min(255, b));
        
        // Write RGB values to buffer
        rgbBytes[rgbIndex++] = r;
        rgbBytes[rgbIndex++] = g;
        rgbBytes[rgbIndex++] = b;
      }
    }
    
    // Create an image from the RGB bytes
    imglib.Image image = imglib.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgbBytes.buffer,
      numChannels: 3,
    );
    
    // Resize image if target dimensions are provided
    if (targetWidth != null && targetHeight != null) {
      image = imglib.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: imglib.Interpolation.cubic,
      );
    }
    
    // Convert to bytes suitable for TFLite
    return Uint8List.fromList(imglib.encodeJpg(image));
  }
  
  /// Normalize and prepare the RGB image for TFLite model input
  static List<List<List<double>>> prepareImageForModel(
    Uint8List imageBytes,
    int inputWidth,
    int inputHeight,
    {bool normalize = true}
  ) {
    // Decode the image
    final image = imglib.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    // Resize if needed
    final resizedImage = imglib.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
    );
    
    // Create a 3D array for [height][width][3] RGB channels
    final result = List.generate(
      inputHeight,
      (_) => List.generate(
        inputWidth,
        (_) => List.filled(3, 0.0),
      ),
    );
    
    // Fill the array with normalized pixel values
    for (int y = 0; y < inputHeight; y++) {
      for (int x = 0; x < inputWidth; x++) {
        // Access color values directly from pixel channels
        // In newer image package versions, getPixel returns a color value
        final pixel = resizedImage.getPixel(x, y);
        final r = pixel.r; // Red channel
        final g = pixel.g; // Green channel
        final b = pixel.b; // Blue channel
        
        // Normalize to [0, 1] or [-1, 1] depending on model requirements
        if (normalize) {
          result[y][x][0] = r / 255.0;
          result[y][x][1] = g / 255.0;
          result[y][x][2] = b / 255.0;
        } else {
          result[y][x][0] = r.toDouble();
          result[y][x][1] = g.toDouble();
          result[y][x][2] = b.toDouble();
        }
      }
    }
    
    return result;
  }
  
  /// An alternative approach: convert CameraImage to a TFLite input tensor directly
  /// This is more efficient as it avoids multiple conversions
  static List<double> imageToTensorInput(
    CameraImage cameraImage,
    int inputWidth,
    int inputHeight,
    {bool normalize = true}
  ) {
    // Get image dimensions
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    // Calculate scaling factors for resizing
    final double scaleWidth = inputWidth / width;
    final double scaleHeight = inputHeight / height;
    
    // Get YUV planes
    final yPlane = cameraImage.planes[0].bytes;
    final uPlane = cameraImage.planes[1].bytes;
    final vPlane = cameraImage.planes[2].bytes;
    
    // Get row strides
    final yRowStride = cameraImage.planes[0].bytesPerRow;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;
    
    // Create a flat list for the input tensor
    final inputTensor = List<double>.filled(inputWidth * inputHeight * 3, 0);
    
    // Process and resize in one go
    for (int y = 0; y < inputHeight; y++) {
      // Find corresponding y in original image
      final srcY = (y / scaleHeight).floor();
      final yIndex = srcY * yRowStride;
      final uvIndex = (srcY ~/ 2) * uvRowStride;
      
      for (int x = 0; x < inputWidth; x++) {
        // Find corresponding x in original image
        final srcX = (x / scaleWidth).floor();
        final uvx = (srcX ~/ 2) * uvPixelStride;
        
        // Get YUV values
        final yValue = yPlane[yIndex + srcX] & 0xff;
        final uValue = uPlane[uvIndex + uvx] & 0xff;
        final vValue = vPlane[uvIndex + uvx] & 0xff;
        
        // Convert YUV to RGB
        int r = yValue + (1.402 * (vValue - 128)).toInt();
        int g = yValue - (0.344136 * (uValue - 128)).toInt() - (0.714136 * (vValue - 128)).toInt();
        int b = yValue + (1.772 * (uValue - 128)).toInt();
        
        // Clamp RGB values
        r = max(0, min(255, r));
        g = max(0, min(255, g));
        b = max(0, min(255, b));
        
        // Calculate position in the tensor
        final baseIndex = (y * inputWidth + x) * 3;
        
        // Normalize if required
        if (normalize) {
          inputTensor[baseIndex] = r / 255.0;
          inputTensor[baseIndex + 1] = g / 255.0;
          inputTensor[baseIndex + 2] = b / 255.0;
        } else {
          inputTensor[baseIndex] = r.toDouble();
          inputTensor[baseIndex + 1] = g.toDouble();
          inputTensor[baseIndex + 2] = b.toDouble();
        }
      }
    }
    
    return inputTensor;
  }
}

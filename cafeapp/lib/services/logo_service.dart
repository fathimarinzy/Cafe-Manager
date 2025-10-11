import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class LogoService {
  static const String _logoPathKey = 'business_logo_path';
  static const String _logoEnabledKey = 'logo_enabled_in_receipts';
  static const String _logoFileName = 'business_logo.png';

  // Get logo file path
  static Future<String?> getLogoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_logoPathKey);
  }

  // Check if logo is enabled for receipts
  static Future<bool> isLogoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_logoEnabledKey) ?? true;
  }

  // Set logo enabled state
  static Future<void> setLogoEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_logoEnabledKey, enabled);
  }

  // Get logo as bytes
  static Future<Uint8List?> getLogoBytes() async {
    try {
      final logoPath = await getLogoPath();
      if (logoPath == null || logoPath.isEmpty) return null;

      final file = File(logoPath);
      if (!await file.exists()) return null;

      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Error reading logo bytes: $e');
      return null;
    }
  }

  // Get resized logo for thermal printing (max 200px width)
  static Future<Uint8List?> getLogoForPrinting() async {
    try {
      final logoBytes = await getLogoBytes();
      if (logoBytes == null) return null;

      final image = img.decodeImage(logoBytes);
      if (image == null) return null;

      // Resize to max 200px width while maintaining aspect ratio
      final resized = img.copyResize(image, width: 200);
      
      // Convert to PNG
      return Uint8List.fromList(img.encodePng(resized));
    } catch (e) {
      debugPrint('Error processing logo for printing: $e');
      return null;
    }
  }

  // Pick and save logo
  static Future<bool> pickAndSaveLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return false;

      // Read image bytes
      final bytes = await image.readAsBytes();
      
      // Decode and validate image
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        debugPrint('Failed to decode image');
        return false;
      }

      // Resize if too large (max 400px width)
      img.Image processedImage = decodedImage;
      if (decodedImage.width > 400) {
        processedImage = img.copyResize(decodedImage, width: 400);
      }

      // Convert to PNG for consistency
      final pngBytes = img.encodePng(processedImage);

      // Save to app directory
      final appDir = await getApplicationDocumentsDirectory();
      final logoFile = File('${appDir.path}/$_logoFileName');
      await logoFile.writeAsBytes(pngBytes);

      // Save path to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_logoPathKey, logoFile.path);

      debugPrint('Logo saved successfully: ${logoFile.path}');
      return true;
    } catch (e) {
      debugPrint('Error picking and saving logo: $e');
      return false;
    }
  }

  // Delete logo
  static Future<bool> deleteLogo() async {
    try {
      final logoPath = await getLogoPath();
      if (logoPath != null && logoPath.isNotEmpty) {
        final file = File(logoPath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logoPathKey);

      debugPrint('Logo deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting logo: $e');
      return false;
    }
  }

  // Get logo as Image widget
  static Future<Widget?> getLogoWidget({
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) async {
    try {
      final logoPath = await getLogoPath();
      if (logoPath == null || logoPath.isEmpty) return null;

      final file = File(logoPath);
      if (!await file.exists()) return null;

      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
      );
    } catch (e) {
      debugPrint('Error loading logo widget: $e');
      return null;
    }
  }

  // Check if logo exists
  static Future<bool> hasLogo() async {
    final logoPath = await getLogoPath();
    if (logoPath == null || logoPath.isEmpty) return false;

    final file = File(logoPath);
    return await file.exists();
  }
}
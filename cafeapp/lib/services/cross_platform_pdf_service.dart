// lib/services/cross_platform_pdf_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/app_localization.dart';

class CrossPlatformPdfService {
  static const MethodChannel _channel = MethodChannel('com.simsrestocafe/file_picker');

  /// Save PDF with cross-platform support
  static Future<bool> savePdf(pw.Document pdf, {String? suggestedFileName}) async {
    try {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final defaultFileName = suggestedFileName ?? 'SIMS_receipt_$timestamp.pdf';

      if (Platform.isAndroid) {
        return await _saveOnAndroid(pdf, defaultFileName);
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return await _saveOnDesktop(pdf, defaultFileName);
      } else if (Platform.isIOS) {
        return await _saveOnIOS(pdf, defaultFileName);
      } else {
        // Fallback for unsupported platforms
        return await _saveFallback(pdf, defaultFileName);
      }
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      return false;
    }
  }

  /// Android-specific PDF saving using existing MethodChannel
  static Future<bool> _saveOnAndroid(pw.Document pdf, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFilename = 'temp_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final tempFile = File('${tempDir.path}/$tempFilename');
      
      await tempFile.writeAsBytes(await pdf.save());
      
      final result = await _channel.invokeMethod('createDocument', {
        'path': tempFile.path,
        'mimeType': 'application/pdf',
        'fileName': fileName,
      });
      
      return result == true;
    } catch (e) {
      debugPrint('Error saving PDF on Android: $e');
      return false;
    }
  }

  /// Desktop PDF saving using file_picker
  static Future<bool> _saveOnDesktop(pw.Document pdf, String fileName) async {
    try {
      // Use file_picker to let user choose save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF Receipt',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(await pdf.save());
        debugPrint('PDF saved to: $result');
        return true;
      }
      
      return false; // User cancelled
    } catch (e) {
      debugPrint('Error saving PDF on desktop: $e');
      return false;
    }
  }

  /// iOS PDF saving (similar to Android but using different approach)
  static Future<bool> _saveOnIOS(pw.Document pdf, String fileName) async {
    try {
      // For iOS, save to Documents directory and let user share
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      
      debugPrint('PDF saved to iOS Documents: ${file.path}');
      return true;
    } catch (e) {
      debugPrint('Error saving PDF on iOS: $e');
      return false;
    }
  }

  /// Fallback method - save to app documents directory
  static Future<bool> _saveFallback(pw.Document pdf, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      
      debugPrint('PDF saved to: ${file.path}');
      return true;
    } catch (e) {
      debugPrint('Error in fallback PDF save: $e');
      return false;
    }
  }

  /// Show save dialog with platform-appropriate message
  static Future<bool?> showSavePdfDialog(BuildContext context) async {
    if (!context.mounted) return null;
    
    String message;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      message = 'Printer not available. Would you like to save the receipt as PDF to your device?'.tr();
    } else if (Platform.isAndroid) {
      message = 'Printer not available. Would you like to save the receipt as PDF?'.tr();
    } else if (Platform.isIOS) {
      message = 'Printer not available. Would you like to save the receipt as PDF to your device?'.tr();
    } else {
      message = 'Printer not available. Would you like to save the receipt as PDF?'.tr();
    }
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Printer Not Available'.tr()),
          content: Text(message.tr()),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'.tr()),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: Text('Save PDF'.tr()),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  /// Get platform-specific save location for display
  static Future<String> getSaveLocationInfo() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'Choose location on your computer';
    } else if (Platform.isAndroid) {
      return 'Downloads folder or chosen location';
    } else if (Platform.isIOS) {
      return 'App Documents folder';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  /// Check if platform supports PDF saving
  static bool get supportsPdfSaving {
    return Platform.isAndroid || 
           Platform.isWindows || 
           Platform.isMacOS || 
           Platform.isLinux || 
           Platform.isIOS;
  }
}
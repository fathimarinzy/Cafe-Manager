import 'dart:io';

import 'package:flutter/services.dart';

/// Raised when the native USB printer channel reports a failure.
///
/// [code] mirrors the native error code so callers can distinguish a denied
/// permission from an unplugged printer without parsing strings.
class UsbPrinterException implements Exception {
  final String code;
  final String message;

  const UsbPrinterException(this.code, this.message);

  /// Human-readable reason suitable for surfacing in the UI.
  String get friendlyMessage {
    switch (code) {
      case 'permission_denied':
        return 'USB permission was denied. Allow access to the printer and try again.';
      case 'permission_timeout':
        return 'Timed out waiting for USB permission. Tap Allow on the permission dialog.';
      case 'not_found':
        return 'USB printer not found. Check that it is plugged in and powered on.';
      case 'not_connected':
        return 'Not connected to the USB printer.';
      case 'open_failed':
        return 'Could not open the USB printer. Unplug and reconnect it, then try again.';
      case 'write_failed':
        return 'Failed to send data to the USB printer: $message';
      case 'unavailable':
        return 'This device does not support USB host mode.';
      case 'missing_plugin':
        return 'USB printer support is missing from this build. Reinstall the app.';
      default:
        return message;
    }
  }

  @override
  String toString() => 'UsbPrinterException($code): $message';
}

/// Android USB thermal-printer transport.
///
/// Backed by [UsbPrinterPlugin] in `android/app/src/main/kotlin/com/example/cafeapp/`.
/// This replaces the abandoned `flutter_usb_printer` package, whose native code used
/// pre-Android-12 PendingIntent flags and crashed SystemUI on permission requests.
class AndroidUsbPrinter {
  static const MethodChannel _channel =
      MethodChannel('com.sims.cafeapp/usb_printer');

  const AndroidUsbPrinter();

  /// Attached USB devices. Empty on non-Android platforms.
  ///
  /// `vendorId` and `productId` come back as strings, matching the
  /// `"<vendorId>_<productId>"` identity keys already persisted in settings.
  static Future<List<Map<String, dynamic>>> listDevices() async {
    if (!Platform.isAndroid) return const [];
    try {
      final devices = await _channel.invokeMethod<List<dynamic>>('list');
      if (devices == null) return const [];
      return devices
          .cast<Map<dynamic, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on MissingPluginException {
      // Stale install: the Dart side is new but the APK on the device is not.
      throw const UsbPrinterException(
          'missing_plugin', 'usb_printer channel is not registered');
    } on PlatformException catch (e) {
      throw UsbPrinterException(e.code, e.message ?? 'Failed to list USB devices');
    }
  }

  /// Claims the printer, requesting USB permission first if it isn't already granted.
  ///
  /// Completes only once the user has answered the system permission dialog.
  /// Throws [UsbPrinterException] on denial, timeout, or a missing device.
  Future<bool> connect(int vendorId, int productId) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('connect', {
        'vendorId': vendorId,
        'productId': productId,
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      throw UsbPrinterException(e.code, e.message ?? 'Failed to connect to USB printer');
    }
  }

  /// Sends raw ESC/POS bytes, chunked natively. Returns only after every byte
  /// has been accepted by the printer's bulk endpoint.
  Future<bool> write(Uint8List data) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('write', {'data': data});
      return ok ?? false;
    } on PlatformException catch (e) {
      throw UsbPrinterException(e.code, e.message ?? 'Failed to write to USB printer');
    }
  }

  /// Releases the interface. Safe to call when nothing is open.
  Future<void> close() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('close');
    } on PlatformException {
      // Closing is best-effort; a failure here must never mask a print result.
    }
  }
}

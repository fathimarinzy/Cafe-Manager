// lib/services/lan_device_discovery.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Zero-config server discovery using UDP broadcast.
/// The server broadcasts its presence and clients listen to find it.
class LanDeviceDiscovery {
  static const int broadcastPort = 8643;
  static const String _magicType = 'cafe_sync_server';

  Timer? _broadcastTimer;
  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenerSocket;

  Function(String message)? onLog;

  // ══════════════════════════════════════════════════════════════════════════
  // Server side: broadcast presence
  // ══════════════════════════════════════════════════════════════════════════

  /// Start broadcasting server presence every [intervalSeconds] seconds.
  Future<void> startBroadcasting({
    required int serverPort,
    required String serverName,
    int intervalSeconds = 2,
  }) async {
    await stopBroadcasting();

    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // Bind to any available port for sending
      );
      _broadcastSocket!.broadcastEnabled = true;

      final payload = jsonEncode({
        'type': _magicType,
        'port': serverPort,
        'name': serverName,
        'timestamp': DateTime.now().toIso8601String(),
      });
      final data = utf8.encode(payload);

      _broadcastTimer = Timer.periodic(
        Duration(seconds: intervalSeconds),
        (_) {
          try {
            _broadcastSocket?.send(
              data,
              InternetAddress('255.255.255.255'),
              broadcastPort,
            );
          } catch (e) {
            _log('Broadcast send error: $e');
          }
        },
      );

      _log('Broadcasting started on port $broadcastPort');
    } catch (e) {
      _log('Failed to start broadcasting: $e');
    }
  }

  /// Stop broadcasting.
  Future<void> stopBroadcasting() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Client side: discover server
  // ══════════════════════════════════════════════════════════════════════════

  /// Listen for server broadcasts and return the server URL when found.
  /// Returns null if no server is found within [timeout].
  Future<String?> discoverServer({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      _listenerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        broadcastPort,
        reuseAddress: true,
        reusePort: true,
      );

      final completer = Completer<String?>();

      _listenerSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenerSocket!.receive();
          if (datagram == null) return;

          try {
            final message = utf8.decode(datagram.data);
            final json = jsonDecode(message) as Map<String, dynamic>;

            if (json['type'] == _magicType) {
              final serverPort = json['port'] as int;
              final serverName = json['name'] as String;
              final serverIp = datagram.address.address;

              _log('Discovered server "$serverName" at $serverIp:$serverPort');

              if (!completer.isCompleted) {
                completer.complete('http://$serverIp:$serverPort');
              }
            }
          } catch (e) {
            _log('Invalid broadcast packet: $e');
          }
        }
      });

      // Set timeout
      Timer(timeout, () {
        if (!completer.isCompleted) {
          _log('Discovery timeout after ${timeout.inSeconds}s');
          completer.complete(null);
        }
      });

      final result = await completer.future;

      // Cleanup
      _listenerSocket?.close();
      _listenerSocket = null;

      return result;
    } catch (e) {
      _log('Discovery error: $e');
      _listenerSocket?.close();
      _listenerSocket = null;
      return null;
    }
  }

  /// Dispose all resources.
  void dispose() {
    stopBroadcasting();
    _listenerSocket?.close();
    _listenerSocket = null;
  }

  void _log(String message) {
    debugPrint('[LanDeviceDiscovery] $message');
    onLog?.call(message);
  }
}

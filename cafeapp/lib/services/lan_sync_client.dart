// lib/services/lan_sync_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/lan_sync_models.dart';

/// HTTP + WebSocket client for LAN sync.
/// Connects to a LanSyncServer on the same network.
class LanSyncClient {
  String? _serverUrl; // e.g., "http://192.168.1.100:8642"
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  bool _intentionalDisconnect = false;

  // Callbacks
  Function(SyncEvent event)? onEventReceived;
  Function(bool connected)? onConnectionChanged;
  Function(String message)? onLog;

  bool get isConnected => _wsChannel != null;
  String? get serverUrl => _serverUrl;

  /// Ping the server to check if it's reachable.
  Future<bool> ping(String serverUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/ping'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      _log('Ping failed: $e');
      return false;
    }
  }

  /// Connect to the server (HTTP + WebSocket).
  Future<bool> connect(String serverUrl) async {
    _serverUrl = serverUrl;
    _intentionalDisconnect = false;

    // First verify the server is reachable
    final reachable = await ping(serverUrl);
    if (!reachable) {
      _log('Server not reachable at $serverUrl');
      return false;
    }

    // Establish WebSocket connection
    return await _connectWebSocket();
  }

  /// Disconnect from the server.
  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _wsSubscription?.cancel();
    _wsSubscription = null;

    try {
      _wsChannel?.sink.close();
    } catch (_) {}
    _wsChannel = null;

    _serverUrl = null;
    onConnectionChanged?.call(false);
    _log('Disconnected from server');
  }

  // ── HTTP Methods (Safety-net sync) ──────────────────────────────────────

  /// Request a full sync (all data) from the server.
  Future<SyncResponse?> requestFullSync() async {
    if (_serverUrl == null) return null;

    try {
      _log('Requesting full sync...');
      final response = await http.get(
        Uri.parse('$_serverUrl/api/sync/full'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final syncResponse = SyncResponse.fromJson(json);
        _log('Full sync received: '
            '${syncResponse.orders.length} orders, '
            '${syncResponse.menuItems.length} menu items');
        return syncResponse;
      }
      _log('Full sync failed: ${response.statusCode}');
      return null;
    } catch (e) {
      _log('Error in full sync: $e');
      return null;
    }
  }

  /// Request incremental sync (changes since lastSyncedAt).
  Future<SyncResponse?> requestIncrementalSync(String lastSyncedAt) async {
    if (_serverUrl == null) return null;

    try {
      _log('Requesting incremental sync since $lastSyncedAt...');
      final response = await http.post(
        Uri.parse('$_serverUrl/api/sync/incremental'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'lastSyncedAt': lastSyncedAt}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return SyncResponse.fromJson(json);
      }
      _log('Incremental sync failed: ${response.statusCode}');
      return null;
    } catch (e) {
      _log('Error in incremental sync: $e');
      return null;
    }
  }

  /// Push local changes to the server.
  Future<bool> pushChanges(SyncPushPayload payload) async {
    if (_serverUrl == null) return false;

    try {
      _log('Pushing ${payload.orders.length} orders, '
          '${payload.menuItems.length} menu items to server...');
      final response = await http.post(
        Uri.parse('$_serverUrl/api/sync/push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload.toJson()),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      _log('Error pushing changes: $e');
      return false;
    }
  }

  /// Get shared settings from the server.
  Future<Map<String, dynamic>?> getSettings() async {
    if (_serverUrl == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/api/sync/settings'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _log('Error getting settings: $e');
      return null;
    }
  }

  // ── WebSocket Methods (Real-time sync) ──────────────────────────────────

  /// Send a sync event to the server via WebSocket.
  void sendEvent(SyncEvent event) {
    if (_wsChannel == null) {
      _log('Cannot send event: not connected');
      return;
    }

    try {
      _wsChannel!.sink.add(event.encode());
    } catch (e) {
      _log('Error sending WS event: $e');
    }
  }

  Future<bool> _connectWebSocket() async {
    if (_serverUrl == null) return false;

    try {
      final wsUrl = '${_serverUrl!.replaceFirst('http://', 'ws://')}/ws';
      _log('Connecting WebSocket to $wsUrl');

      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait for connection to be ready
      await _wsChannel!.ready;

      _wsSubscription = _wsChannel!.stream.listen(
        (message) {
          try {
            final event = SyncEvent.decode(message as String);
            _log('Received WS event: ${event.event}');
            onEventReceived?.call(event);
          } catch (e) {
            _log('Error parsing WS message: $e');
          }
        },
        onDone: () {
          _log('WebSocket connection closed');
          _wsChannel = null;
          _wsSubscription = null;
          onConnectionChanged?.call(false);
          _scheduleReconnect();
        },
        onError: (error) {
          _log('WebSocket error: $error');
          _wsChannel = null;
          _wsSubscription = null;
          onConnectionChanged?.call(false);
          _scheduleReconnect();
        },
      );

      onConnectionChanged?.call(true);
      _log('WebSocket connected');
      return true;
    } catch (e) {
      _log('WebSocket connection failed: $e');
      _wsChannel = null;
      onConnectionChanged?.call(false);
      _scheduleReconnect();
      return false;
    }
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || _serverUrl == null) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      _log('Attempting to reconnect...');
      final success = await _connectWebSocket();
      if (!success) {
        _scheduleReconnect(); // Keep trying
      }
    });
  }

  void _log(String message) {
    debugPrint('[LanSyncClient] $message');
    onLog?.call(message);
  }
}

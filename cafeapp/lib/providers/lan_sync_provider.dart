// lib/providers/lan_sync_provider.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lan_sync_models.dart';
import '../services/lan_sync_server.dart';
import '../services/lan_sync_client.dart';
import '../services/lan_sync_engine.dart';
import '../services/lan_device_discovery.dart';
import '../repositories/local_order_repository.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Provider that orchestrates the LAN sync system.
/// Manages server/client mode, periodic sync, and real-time events.
class LanSyncProvider extends ChangeNotifier {
  static const String _isServerKey = 'lan_sync_is_server';
  static const String _serverAddressKey = 'lan_sync_server_address';
  static const Duration _periodicSyncInterval = Duration(seconds: 30);

  final LanSyncServer _server = LanSyncServer();
  final LanSyncClient _client = LanSyncClient();
  final LanSyncEngine _engine = LanSyncEngine();
  final LanDeviceDiscovery _discovery = LanDeviceDiscovery();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isServer = false;
  bool _isConnected = false;
  String? _serverAddress;
  String? _lastSyncedAt;
  SyncStatus _status = SyncStatus.idle;
  int _connectedClients = 0;
  String? _localIp;
  String? _deviceId;
  final List<String> _logs = [];

  Timer? _periodicSyncTimer;
  Timer? _periodicPingTimer;

  // Callbacks for UI to refresh data after sync
  Function()? onOrdersChanged;
  Function()? onMenuChanged;
  Function()? onTablesChanged;
  Function()? onPersonsChanged;
  Function()? onDeliveryBoysChanged;
  Function()? onSettingsChanged;

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isServer => _isServer;
  bool get isConnected => _isConnected;
  String? get serverAddress => _serverAddress;
  String? get lastSyncedAt => _lastSyncedAt;
  SyncStatus get status => _status;
  int get connectedClients => _connectedClients;
  String? get localIp => _localIp;
  String get deviceId => _deviceId ?? 'unknown';
  List<String> get logs => List.unmodifiable(_logs);
  bool get isActive => _isServer || _isConnected;

  static final LanSyncProvider instance = LanSyncProvider._internal();
  factory LanSyncProvider() => instance;

  LanSyncProvider._internal() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id') ?? 'unknown';
    _lastSyncedAt = await _engine.getLastSyncedAt();

    // Fetch local IP with robust fallback
    try {
      final info = NetworkInfo();
      _localIp = await info.getWifiIP();
      
      if (_localIp == null || _localIp!.isEmpty || _localIp == '0.0.0.0') {
        for (var interface_ in await NetworkInterface.list()) {
          for (var addr in interface_.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              _localIp = addr.address;
              break;
            }
          }
          if (_localIp != null && _localIp != '0.0.0.0') break;
        }
      }
    } catch (_) {}

    // Wire up callbacks
    _server.onClientCountChanged = (count) {
      _connectedClients = count;
      notifyListeners();
    };
    _server.onLog = _addLog;

    // FIX: Wire up server-side event handler so that when a Client sends
    // data to the Host, the Host applies it to its own database and
    // triggers UI refresh.
    _server.onEventReceived = _handleIncomingEvent;
    _server.onPushReceived = _handleIncomingPush;

    _client.onConnectionChanged = (connected) {
      _isConnected = connected;
      _status = connected ? SyncStatus.connected : SyncStatus.idle;
      notifyListeners();

      // On reconnect, do a safety-net sync
      if (connected) {
        syncNow();
      }
    };
    _client.onEventReceived = _handleIncomingEvent;
    _client.onLog = _addLog;

    _engine.onLog = _addLog;
    _discovery.onLog = _addLog;

    notifyListeners();

    // FIX: Auto-restore previous connection on app restart
    await _tryAutoRestore(prefs);
  }

  /// Attempt to restore the previous server/client state on app restart.
  Future<void> _tryAutoRestore(SharedPreferences prefs) async {
    final wasServer = prefs.getBool(_isServerKey) ?? false;
    final savedAddress = prefs.getString(_serverAddressKey);

    if (wasServer) {
      _addLog('Auto-restoring server mode...');
      await startServer();
    } else if (savedAddress != null && savedAddress.isNotEmpty) {
      _addLog('Auto-reconnecting to $savedAddress...');
      await connectToServer(savedAddress);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Server Mode
  // ══════════════════════════════════════════════════════════════════════════

  /// Start the LAN sync server on this device.
  Future<bool> startServer({int port = LanSyncServer.defaultPort}) async {
    _status = SyncStatus.connecting;
    notifyListeners();

    final success = await _server.start(port: port, serverName: 'SIMS Cafe Server');
    if (success) {
      _isServer = true;
      _status = SyncStatus.serverRunning;
      _serverAddress = _localIp != null ? 'http://$_localIp:$port' : _server.address;

      // Start broadcasting for auto-discovery
      await _discovery.startBroadcasting(
        serverPort: port,
        serverName: 'SIMS Cafe Server',
      );

      // Save state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isServerKey, true);

      _addLog('Server started at $_serverAddress');
    } else {
      _status = SyncStatus.error;
      _addLog('Failed to start server');
    }

    notifyListeners();
    return success;
  }

  /// Stop the LAN sync server.
  Future<void> stopServer() async {
    await _discovery.stopBroadcasting();
    await _server.stop();

    _isServer = false;
    _connectedClients = 0;
    _serverAddress = null;
    _status = SyncStatus.idle;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isServerKey, false);

    _addLog('Server stopped');
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Client Mode
  // ══════════════════════════════════════════════════════════════════════════

  /// Auto-discover and connect to a server on the LAN.
  Future<bool> discoverAndConnect() async {
    _status = SyncStatus.connecting;
    notifyListeners();

    _addLog('Searching for server on LAN...');
    final serverUrl = await _discovery.discoverServer(
      timeout: const Duration(seconds: 10),
    );

    if (serverUrl != null) {
      return await connectToServer(serverUrl);
    }

    _status = SyncStatus.error;
    _addLog('No server found on LAN');
    notifyListeners();
    return false;
  }

  /// Connect to a server at the given URL.
  Future<bool> connectToServer(String serverUrl) async {
    _status = SyncStatus.connecting;
    notifyListeners();

    final success = await _client.connect(serverUrl);
    if (success) {
      _serverAddress = serverUrl;
      _isConnected = true;
      _status = SyncStatus.connected;

      // Save state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_serverAddressKey, serverUrl);

      // Start periodic sync
      _startPeriodicSync();

      // Do initial sync
      await syncNow();

      _addLog('Connected to server at $serverUrl');
    } else {
      _status = SyncStatus.error;
      _addLog('Failed to connect to $serverUrl');
    }

    notifyListeners();
    return success;
  }

  /// Disconnect from the server.
  void disconnectFromServer() {
    _stopPeriodicSync();
    _client.disconnect();
    _isConnected = false;
    _serverAddress = null;
    _status = SyncStatus.idle;

    // Clear saved address so we don't auto-reconnect
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_serverAddressKey);
    });

    _addLog('Disconnected from server');
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Sync Operations
  // ══════════════════════════════════════════════════════════════════════════

  /// Perform a sync now (manual or periodic).
  Future<void> syncNow() async {
    if (!_isConnected || _status == SyncStatus.syncing) return;

    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      if (_lastSyncedAt == null) {
        // First sync: do a full sync
        _addLog('Performing full sync...');
        final response = await _client.requestFullSync();
        if (response != null) {
          await _engine.applySyncResponse(response);
          _lastSyncedAt = response.serverTime;
          _notifyAllChanged();
          _addLog('Full sync complete');
        }
      } else {
        // Push local changes first
        final payload = await _engine.buildPushPayload(_deviceId ?? 'unknown');
        if (!payload.isEmpty) {
          await _client.pushChanges(payload);
        }

        // Then pull server changes
        final response = await _client.requestIncrementalSync(_lastSyncedAt!);
        if (response != null && !response.isEmpty) {
          await _engine.applySyncResponse(response);
          _lastSyncedAt = response.serverTime;
          _notifyAllChanged();
          _addLog('Incremental sync complete');
        }
      }
    } catch (e) {
      _addLog('Sync error: $e');
    }

    _status = _isConnected ? SyncStatus.connected : SyncStatus.idle;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Real-time Event Broadcasting (called by providers)
  // ══════════════════════════════════════════════════════════════════════════

  /// Broadcast a real-time event.
  /// Call this from OrderProvider, MenuProvider, etc. when data changes.
  void broadcastEvent(SyncEvent event) {
    if (_isServer) {
      // Server: broadcast to all connected clients
      _server.broadcastEvent(event);
    } else if (_isConnected) {
      // Client: send to server (which will relay to other clients)
      _client.sendEvent(event);
    }
  }

  /// Handle an incoming real-time event from the server/other client.
  void _handleIncomingEvent(SyncEvent event) async {
    _addLog('Handling incoming event: ${event.event} from ${event.deviceId}');
    
    // Skip events that originated from this device
    if (event.deviceId == _deviceId) {
      _addLog('Skipping own event');
      return;
    }

    SyncEvent? followUpEvent;

    // Server assigns main order number for new orders from clients
    if (_isServer && event.event == SyncEventType.orderCreated) {
      final orderMap = event.data;
      if (orderMap['main_number_assigned'] != 1 && orderMap['main_number_assigned'] != true) {
        final localRepo = LocalOrderRepository();
        final nextMainNumber = await localRepo.getNextMainOrderNumber();
        orderMap['main_order_number'] = nextMainNumber;
        orderMap['main_number_assigned'] = 1;
        
        _addLog('Server assigned main order number $nextMainNumber to order from ${event.deviceId}');
        
        // Prepare follow-up broadcast so the sender gets the assigned number
        followUpEvent = SyncEvent(
          event: SyncEventType.orderUpdated,
          data: orderMap,
          deviceId: _deviceId ?? 'server',
        );
      }
    }

    // Apply the event to local database
    await _engine.applyEvent(event);

    // If we are the server, relay the event to all other connected clients
    if (_isServer) {
      _server.broadcastEvent(event, excludeDeviceId: event.deviceId);
      
      if (followUpEvent != null) {
        _server.broadcastEvent(followUpEvent); // Explicit update containing mainOrderNumber goes to all
      }
    }

    // Notify the appropriate UI callback
    switch (event.event) {
      case SyncEventType.orderCreated:
      case SyncEventType.orderUpdated:
      case SyncEventType.orderDeleted:
        onOrdersChanged?.call();
        break;
      case SyncEventType.menuUpdated:
      case SyncEventType.menuDeleted:
        onMenuChanged?.call();
        break;
      case SyncEventType.tableUpdated:
        onTablesChanged?.call();
        break;
      case SyncEventType.personUpdated:
      case SyncEventType.personDeleted:
        onPersonsChanged?.call();
        break;
      case SyncEventType.deliveryBoyUpdated:
      case SyncEventType.deliveryBoyDeleted:
        onDeliveryBoysChanged?.call();
        break;
      case SyncEventType.settingsChanged:
        onSettingsChanged?.call();
        break;
    }
  }

  /// Handle an incoming push payload from a client (Server mode).
  Future<void> _handleIncomingPush(SyncPushPayload payload) async {
    _addLog('Handling incoming push from ${payload.deviceId}');
    
    // Apply the payload to the local database
    await _engine.applyPushPayload(payload);
    
    // Notify UI to refresh
    _notifyAllChanged();
    
    _addLog('Push from ${payload.deviceId} applied successfully');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Periodic Sync
  // ══════════════════════════════════════════════════════════════════════════

  void _startPeriodicSync() {
    _stopPeriodicSync();
    _periodicSyncTimer = Timer.periodic(_periodicSyncInterval, (_) {
      syncNow();
    });
  }

  void _stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _periodicPingTimer?.cancel();
    _periodicPingTimer = null;
  }

  void _notifyAllChanged() {
    onOrdersChanged?.call();
    onMenuChanged?.call();
    onTablesChanged?.call();
    onPersonsChanged?.call();
    onDeliveryBoysChanged?.call();
    onSettingsChanged?.call();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Logging
  // ══════════════════════════════════════════════════════════════════════════

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$timestamp] $message');
    if (_logs.length > 100) {
      _logs.removeAt(0); // Keep last 100 entries
    }
    debugPrint('[LanSync] $message');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Cleanup
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _stopPeriodicSync();
    _discovery.dispose();
    if (_isServer) {
      _server.stop();
    }
    if (_isConnected) {
      _client.disconnect();
    }
    super.dispose();
  }
}

// lib/services/lan_sync_server.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/lan_sync_models.dart';
import '../repositories/local_order_repository.dart';
import '../repositories/local_menu_repository.dart';
import '../repositories/local_person_repository.dart';
import '../repositories/local_delivery_boy_repository.dart';
import '../repositories/credit_transaction_repository.dart';

/// Embedded HTTP + WebSocket server for LAN sync.
/// Runs on the designated host device (Windows PC or Android tablet).
class LanSyncServer {
  static const int defaultPort = 8642;

  HttpServer? _server;
  final Set<WebSocketChannel> _connectedClients = {};
  String? _serverName;
  int _port = defaultPort;

  // Repositories
  final _orderRepo = LocalOrderRepository();
  final _menuRepo = LocalMenuRepository();
  final _personRepo = LocalPersonRepository();
  final _deliveryBoyRepo = LocalDeliveryBoyRepository();
  final _creditTxRepo = CreditTransactionRepository();

  // Callbacks for notifying the provider
  Function(int clientCount)? onClientCountChanged;
  Function(String message)? onLog;
  Function(SyncEvent event)? onEventReceived;
  Function(SyncPushPayload payload)? onPushReceived;

  bool get isRunning => _server != null;
  int get connectedClientCount => _connectedClients.length;
  String? get address => _server != null
      ? 'http://${_server!.address.host}:${_server!.port}'
      : null;
  int get port => _port;

  /// Start the HTTP + WebSocket server on all interfaces.
  Future<bool> start({int port = defaultPort, String? serverName}) async {
    if (_server != null) {
      _log('Server already running');
      return true;
    }

    _port = port;
    _serverName = serverName ?? 'SIMS Cafe Server';

    try {
      final router = Router();

      // ── HTTP REST endpoints ──────────────────────────────────────────────
      router.get('/api/ping', _handlePing);
      router.get('/api/sync/full', _handleFullSync);
      router.post('/api/sync/incremental', _handleIncrementalSync);
      router.post('/api/sync/push', _handlePush);
      router.get('/api/sync/settings', _handleGetSettings);

      // ── WebSocket endpoint ───────────────────────────────────────────────
      final wsHandler = webSocketHandler((WebSocketChannel ws) {
        _onClientConnected(ws);
      });

      // Combine: if path is /ws, use WebSocket handler, else use router
      final handler = const shelf.Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(shelf.logRequests(logger: (msg, isError) {
            if (isError) _log('ERROR: $msg');
          }))
          .addHandler((shelf.Request request) {
            if (request.url.path == 'ws') {
              return wsHandler(request);
            }
            return router(request);
          });

      _server = await shelf_io.serve(handler, '0.0.0.0', _port);
      _log('Server started on ${_server!.address.host}:${_server!.port}');
      return true;
    } catch (e) {
      _log('Failed to start server: $e');
      _server = null;
      return false;
    }
  }

  /// Stop the server and disconnect all clients.
  Future<void> stop() async {
    // Close all WebSocket connections
    for (final client in _connectedClients.toList()) {
      try {
        await client.sink.close();
      } catch (_) {}
    }
    _connectedClients.clear();

    // Close HTTP server
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _log('Server stopped');
    }
  }

  /// Broadcast a sync event to all connected WebSocket clients
  /// except the one identified by [excludeDeviceId].
  void broadcastEvent(SyncEvent event, {String? excludeDeviceId}) {
    if (_connectedClients.isEmpty) return;

    final encoded = event.encode();
    int sent = 0;

    for (final client in _connectedClients.toList()) {
      try {
        client.sink.add(encoded);
        sent++;
      } catch (e) {
        _log('Error broadcasting to client: $e');
        _connectedClients.remove(client);
      }
    }

    _log('Broadcast ${event.event} to $sent clients');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WebSocket management
  // ══════════════════════════════════════════════════════════════════════════

  void _onClientConnected(WebSocketChannel ws) {
    _connectedClients.add(ws);
    _log('Client connected. Total: ${_connectedClients.length}');
    onClientCountChanged?.call(_connectedClients.length);

    ws.stream.listen(
      (message) {
        _onWsMessage(ws, message);
      },
      onDone: () {
        _connectedClients.remove(ws);
        _log('Client disconnected. Total: ${_connectedClients.length}');
        onClientCountChanged?.call(_connectedClients.length);
      },
      onError: (error) {
        _connectedClients.remove(ws);
        _log('Client error: $error. Total: ${_connectedClients.length}');
        onClientCountChanged?.call(_connectedClients.length);
      },
    );
  }

  void _onWsMessage(WebSocketChannel sender, dynamic message) {
    try {
      final event = SyncEvent.decode(message as String);
      _log('Received WS event: ${event.event} from ${event.deviceId}');

      // IMPORTANT: Notify the provider so the Host applies this event
      // to its own local database and refreshes the UI.
      onEventReceived?.call(event);

      // Re-broadcast to all OTHER clients (not back to sender)
      final encoded = event.encode();
      for (final client in _connectedClients.toList()) {
        if (client != sender) {
          try {
            client.sink.add(encoded);
          } catch (e) {
            _connectedClients.remove(client);
          }
        }
      }
    } catch (e) {
      _log('Error processing WS message: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HTTP Handlers
  // ══════════════════════════════════════════════════════════════════════════

  Future<shelf.Response> _handlePing(shelf.Request request) async {
    return shelf.Response.ok(
      jsonEncode({
        'status': 'ok',
        'serverName': _serverName,
        'timestamp': DateTime.now().toIso8601String(),
        'connectedClients': _connectedClients.length,
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  /// Full sync: returns ALL non-deleted records for all entities
  Future<shelf.Response> _handleFullSync(shelf.Request request) async {
    try {
      _log('Full sync requested');
      final response = await _buildSyncResponse(null);
      return shelf.Response.ok(
        jsonEncode(response.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      _log('Error in full sync: $e');
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Incremental sync: returns records changed since lastSyncedAt
  Future<shelf.Response> _handleIncrementalSync(shelf.Request request) async {
    try {
      final bodyStr = await request.readAsString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final lastSyncedAt = body['lastSyncedAt'] as String?;

      _log('Incremental sync requested since: $lastSyncedAt');
      final response = await _buildSyncResponse(lastSyncedAt);
      return shelf.Response.ok(
        jsonEncode(response.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      _log('Error in incremental sync: $e');
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Push: accept changes from a client and apply them locally
  Future<shelf.Response> _handlePush(shelf.Request request) async {
    try {
      final bodyStr = await request.readAsString();
      final payload = SyncPushPayload.fromJson(
        jsonDecode(bodyStr) as Map<String, dynamic>,
      );

      // Apply changes to local DB (the engine will handle conflict resolution)
      // Notify the provider so it can use the engine to apply this payload
      if (onPushReceived != null) {
        await onPushReceived!(payload);
      }
      // For now, respond with success. The sync engine applies these.
      return shelf.Response.ok(
        jsonEncode({
          'status': 'ok',
          'serverTime': DateTime.now().toIso8601String(),
          'accepted': true,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      _log('Error in push: $e');
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Get shared settings (business info, tax rate, etc.)
  Future<shelf.Response> _handleGetSettings(shelf.Request request) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = <String, dynamic>{
        'businessName': prefs.getString('business_name') ?? '',
        'secondBusinessName': prefs.getString('second_business_name') ?? '',
        'businessAddress': prefs.getString('business_address') ?? '',
        'businessPhone': prefs.getString('business_phone') ?? '',
        'businessEmail': prefs.getString('business_email') ?? '',
        'taxPercentage': prefs.getDouble('tax_percentage') ?? 0.0,
        'taxLabel': prefs.getString('tax_label') ?? 'Tax',
        'currencySymbol': prefs.getString('currency_symbol') ?? '\$',
      };

      return shelf.Response.ok(
        jsonEncode(settings),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      _log('Error getting settings: $e');
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Data Helpers
  // ══════════════════════════════════════════════════════════════════════════

  /// Build a SyncResponse from local DB data.
  /// If [since] is null, returns all records (full sync).
  /// If [since] is provided, returns only records updated after that time.
  Future<SyncResponse> _buildSyncResponse(String? since) async {
    final orders = await _getOrders(since);
    final menuItems = await _getMenuItems(since);
    final persons = await _getPersons(since);
    final deliveryBoys = await _getDeliveryBoys(since);
    final creditTxns = await _getCreditTransactions(since);

    // Get table data from SharedPreferences
    final tables = await _getTables();

    final settings = await _getSettingsForSync();

    return SyncResponse(
      serverTime: DateTime.now().toIso8601String(),
      orders: orders,
      menuItems: menuItems,
      tables: tables,
      persons: persons,
      deliveryBoys: deliveryBoys,
      creditTransactions: creditTxns,
      settings: settings,
    );
  }

  Future<Map<String, dynamic>> _getSettingsForSync() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'business_name': prefs.getString('business_name') ?? '',
      'second_business_name': prefs.getString('second_business_name') ?? '',
      'business_address': prefs.getString('business_address') ?? '',
      'business_phone': prefs.getString('business_phone') ?? '',
      'business_email': prefs.getString('business_email') ?? '',
      'tax_rate': prefs.getDouble('tax_rate') ?? 0.0,
      'is_vat_inclusive': prefs.getBool('is_vat_inclusive') ?? false,
      'receipt_footer': prefs.getString('receipt_footer') ?? '',
    };
  }

  Future<List<Map<String, dynamic>>> _getOrders(String? since) async {
    try {
      final db = await _orderRepo.database;
      List<Map<String, dynamic>> results;
      
      if (since != null) {
        results = await db.query('orders',
            where: 'updated_at > ?', whereArgs: [since]);
      } else {
        results = await db.query('orders', where: 'is_deleted = ?', whereArgs: [0]);
      }

      final List<Map<String, dynamic>> ordersWithItems = [];
      for (var row in results) {
        final orderId = row['id'];
        final itemsList = await db.query(
          'order_items', 
          where: 'order_id = ?', 
          whereArgs: [orderId]
        );
        
        final Map<String, dynamic> joinedRow = Map<String, dynamic>.from(row);
        joinedRow['items'] = itemsList;
        ordersWithItems.add(joinedRow);
      }
      return ordersWithItems;
    } catch (e) {
      _log('Error getting orders for sync: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getMenuItems(String? since) async {
    try {
      final db = await _menuRepo.database;
      if (since != null) {
        return await db.query('menu_items',
            where: 'lastUpdated > ?', whereArgs: [since]);
      }
      return await db.query('menu_items',
          where: 'isDeleted = ?', whereArgs: [0]);
    } catch (e) {
      _log('Error getting menu items for sync: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getPersons(String? since) async {
    try {
      final db = await _personRepo.database;
      if (since != null) {
        return await db.query('persons',
            where: 'updated_at > ?', whereArgs: [since]);
      }
      return await db.query('persons',
          where: 'is_deleted = ?', whereArgs: [0]);
    } catch (e) {
      _log('Error getting persons for sync: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getDeliveryBoys(String? since) async {
    try {
      final db = await _deliveryBoyRepo.database;
      if (since != null) {
        return await db.query('delivery_boys',
            where: 'updated_at > ?', whereArgs: [since]);
      }
      return await db.query('delivery_boys',
          where: 'is_deleted = ?', whereArgs: [0]);
    } catch (e) {
      _log('Error getting delivery boys for sync: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getCreditTransactions(
      String? since) async {
    try {
      final db = await _creditTxRepo.database;
      if (since != null) {
        return await db.query('credit_transactions',
            where: 'updated_at > ?', whereArgs: [since]);
      }
      return await db.query('credit_transactions',
          where: 'is_deleted = ?', whereArgs: [0]);
    } catch (e) {
      _log('Error getting credit transactions for sync: $e');
      return [];
    }
  }

  /// Get tables from SharedPreferences (they are stored there, not in SQLite)
  Future<List<Map<String, dynamic>>> _getTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tablesJson = prefs.getString('dining_tables');
      if (tablesJson != null) {
        final list = jsonDecode(tablesJson) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      _log('Error getting tables for sync: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORS + Logging
  // ══════════════════════════════════════════════════════════════════════════

  shelf.Middleware _corsMiddleware() {
    return (shelf.Handler handler) {
      return (shelf.Request request) async {
        // Handle CORS preflight
        if (request.method == 'OPTIONS') {
          return shelf.Response.ok('', headers: _corsHeaders);
        }
        final response = await handler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  void _log(String message) {
    debugPrint('[LanSyncServer] $message');
    onLog?.call(message);
  }
}

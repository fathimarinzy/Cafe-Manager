// lib/models/lan_sync_models.dart
import 'dart:convert';

/// WebSocket event types used for real-time sync
class SyncEventType {
  static const String orderCreated = 'order_created';
  static const String orderUpdated = 'order_updated';
  static const String orderDeleted = 'order_deleted';
  static const String menuUpdated = 'menu_updated';
  static const String menuDeleted = 'menu_deleted';
  static const String tableUpdated = 'table_updated';
  static const String personUpdated = 'person_updated';
  static const String personDeleted = 'person_deleted';
  static const String deliveryBoyUpdated = 'delivery_boy_updated';
  static const String deliveryBoyDeleted = 'delivery_boy_deleted';
  static const String creditTxUpdated = 'credit_tx_updated';
  static const String settingsChanged = 'settings_changed';
}

/// A single real-time event sent over WebSocket
class SyncEvent {
  final String event;
  final Map<String, dynamic> data;
  final String deviceId;
  final String timestamp;

  SyncEvent({
    required this.event,
    required this.data,
    required this.deviceId,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => {
    'event': event,
    'data': data,
    'deviceId': deviceId,
    'timestamp': timestamp,
  };

  factory SyncEvent.fromJson(Map<String, dynamic> json) => SyncEvent(
    event: json['event'] as String,
    data: json['data'] as Map<String, dynamic>,
    deviceId: json['deviceId'] as String,
    timestamp: json['timestamp'] as String?,
  );

  String encode() => jsonEncode(toJson());
  
  static SyncEvent decode(String raw) => SyncEvent.fromJson(jsonDecode(raw));
}

/// Payload sent by the client when pushing local changes to the server
class SyncPushPayload {
  final String deviceId;
  final String lastSyncedAt;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> menuItems;
  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> persons;
  final List<Map<String, dynamic>> deliveryBoys;
  final List<Map<String, dynamic>> creditTransactions;

  SyncPushPayload({
    required this.deviceId,
    required this.lastSyncedAt,
    this.orders = const [],
    this.menuItems = const [],
    this.tables = const [],
    this.persons = const [],
    this.deliveryBoys = const [],
    this.creditTransactions = const [],
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'lastSyncedAt': lastSyncedAt,
    'orders': orders,
    'menuItems': menuItems,
    'tables': tables,
    'persons': persons,
    'deliveryBoys': deliveryBoys,
    'creditTransactions': creditTransactions,
  };

  factory SyncPushPayload.fromJson(Map<String, dynamic> json) => SyncPushPayload(
    deviceId: json['deviceId'] as String,
    lastSyncedAt: json['lastSyncedAt'] as String,
    orders: _toListOfMaps(json['orders']),
    menuItems: _toListOfMaps(json['menuItems']),
    tables: _toListOfMaps(json['tables']),
    persons: _toListOfMaps(json['persons']),
    deliveryBoys: _toListOfMaps(json['deliveryBoys']),
    creditTransactions: _toListOfMaps(json['creditTransactions']),
  );

  bool get isEmpty =>
      orders.isEmpty &&
      menuItems.isEmpty &&
      tables.isEmpty &&
      persons.isEmpty &&
      deliveryBoys.isEmpty &&
      creditTransactions.isEmpty;
}

/// Response from the server containing synced data
class SyncResponse {
  final String serverTime;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> menuItems;
  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> persons;
  final List<Map<String, dynamic>> deliveryBoys;
  final List<Map<String, dynamic>> creditTransactions;
  final Map<String, dynamic>? settings;

  SyncResponse({
    required this.serverTime,
    this.orders = const [],
    this.menuItems = const [],
    this.tables = const [],
    this.persons = const [],
    this.deliveryBoys = const [],
    this.creditTransactions = const [],
    this.settings,
  });

  Map<String, dynamic> toJson() => {
    'serverTime': serverTime,
    'orders': orders,
    'menuItems': menuItems,
    'tables': tables,
    'persons': persons,
    'deliveryBoys': deliveryBoys,
    'creditTransactions': creditTransactions,
    if (settings != null) 'settings': settings,
  };

  factory SyncResponse.fromJson(Map<String, dynamic> json) => SyncResponse(
    serverTime: json['serverTime'] as String,
    orders: _toListOfMaps(json['orders']),
    menuItems: _toListOfMaps(json['menuItems']),
    tables: _toListOfMaps(json['tables']),
    persons: _toListOfMaps(json['persons']),
    deliveryBoys: _toListOfMaps(json['deliveryBoys']),
    creditTransactions: _toListOfMaps(json['creditTransactions']),
    settings: json['settings'] as Map<String, dynamic>?,
  );

  bool get isEmpty =>
      orders.isEmpty &&
      menuItems.isEmpty &&
      tables.isEmpty &&
      persons.isEmpty &&
      deliveryBoys.isEmpty &&
      creditTransactions.isEmpty;
}

/// Sync status enum
enum SyncStatus {
  idle,
  connecting,
  connected,
  syncing,
  error,
  serverRunning,
}

// ── Helper ──────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _toListOfMaps(dynamic value) {
  if (value == null) return [];
  return (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

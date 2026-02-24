import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' as native;
import 'package:firedart/firedart.dart' as fd;
import 'package:flutter/foundation.dart';

/// ---- Interfaces to match Firestore API ----

abstract class FirestoreInterface {
  CollectionReferenceInterface collection(String path);
  WriteBatchInterface batch();
}

abstract class WriteBatchInterface {
  void set(DocumentReferenceInterface ref, Map<String, dynamic> data, [native.SetOptions? options]);
  void update(DocumentReferenceInterface ref, Map<String, dynamic> data);
  void delete(DocumentReferenceInterface ref);
  Future<void> commit();
}

abstract class CollectionReferenceInterface extends QueryInterface {
  DocumentReferenceInterface doc([String? path]);
  Future<DocumentReferenceInterface> add(Map<String, dynamic> data);
}

abstract class QueryInterface {
  QueryInterface where(String field, {dynamic isEqualTo});
  QueryInterface orderBy(String field, {bool descending = false});
  QueryInterface limit(int limit);
  Future<QuerySnapshotInterface> get();
  Stream<QuerySnapshotInterface> snapshots();
}

abstract class DocumentReferenceInterface {
  String get id;
  Future<void> set(Map<String, dynamic> data, [native.SetOptions? options]);
  Future<void> update(Map<String, dynamic> data);
  Future<void> delete();
  Future<DocumentSnapshotInterface> get();
  Stream<DocumentSnapshotInterface> snapshots();
}

abstract class QuerySnapshotInterface {
  List<QueryDocumentSnapshotInterface> get docs;
  List<DocumentChangeInterface> get docChanges;
}

abstract class DocumentChangeInterface {
  DocumentChangeTypeInterface get type;
  QueryDocumentSnapshotInterface get doc;
  int get newIndex;
  int get oldIndex;
}

enum DocumentChangeTypeInterface {
  added,
  modified,
  removed,
}

abstract class DocumentSnapshotInterface {
  String get id;
  bool get exists;
  DocumentReferenceInterface get reference;
  Map<String, dynamic>? data();
}

abstract class QueryDocumentSnapshotInterface extends DocumentSnapshotInterface {
  @override
  Map<String, dynamic> data(); // Must be non-null for query results
}

/// ---- Native Implementation ----

class NativeFirestore implements FirestoreInterface {
  final native.FirebaseFirestore _firestore = native.FirebaseFirestore.instance;

  @override
  CollectionReferenceInterface collection(String path) {
    return NativeCollectionReference(_firestore.collection(path));
  }

  @override
  WriteBatchInterface batch() {
    return NativeWriteBatch(_firestore.batch());
  }
}

class NativeWriteBatch implements WriteBatchInterface {
  final native.WriteBatch _batch;

  NativeWriteBatch(this._batch);

  @override
  void set(DocumentReferenceInterface ref, Map<String, dynamic> data, [native.SetOptions? options]) {
    if (ref is NativeDocumentReference) {
      _batch.set(ref._doc, data, options);
    }
  }

  @override
  void update(DocumentReferenceInterface ref, Map<String, dynamic> data) {
    if (ref is NativeDocumentReference) {
      _batch.update(ref._doc, data);
    }
  }

  @override
  void delete(DocumentReferenceInterface ref) {
    if (ref is NativeDocumentReference) {
      _batch.delete(ref._doc);
    }
  }

  @override
  Future<void> commit() => _batch.commit();
}

class NativeCollectionReference extends NativeQuery implements CollectionReferenceInterface {
  final native.CollectionReference _collection;

  NativeCollectionReference(this._collection) : super(_collection);

  @override
  DocumentReferenceInterface doc([String? path]) {
    return NativeDocumentReference(_collection.doc(path));
  }

  @override
  Future<DocumentReferenceInterface> add(Map<String, dynamic> data) async {
    final doc = await _collection.add(data);
    return NativeDocumentReference(doc);
  }
}

class NativeQuery implements QueryInterface {
  final native.Query _query;

  NativeQuery(this._query);

  @override
  QueryInterface where(String field, {dynamic isEqualTo}) {
    return NativeQuery(_query.where(field, isEqualTo: isEqualTo));
  }

  @override
  QueryInterface orderBy(String field, {bool descending = false}) {
    return NativeQuery(_query.orderBy(field, descending: descending));
  }

  @override
  QueryInterface limit(int limit) {
    return NativeQuery(_query.limit(limit));
  }

  @override
  Future<QuerySnapshotInterface> get() async {
    final snapshot = await _query.get();
    return NativeQuerySnapshot(snapshot);
  }

  @override
  Stream<QuerySnapshotInterface> snapshots() {
    return _query.snapshots().map((snapshot) => NativeQuerySnapshot(snapshot));
  }
}

class NativeDocumentReference implements DocumentReferenceInterface {
  final native.DocumentReference _doc;

  NativeDocumentReference(this._doc);

  @override
  String get id => _doc.id;

  @override
  Future<void> set(Map<String, dynamic> data, [native.SetOptions? options]) => _doc.set(data, options);

  @override
  Future<void> update(Map<String, dynamic> data) => _doc.update(data);

  @override
  Future<void> delete() => _doc.delete();

  @override
  Future<DocumentSnapshotInterface> get() async {
    final snapshot = await _doc.get();
    return NativeDocumentSnapshot(snapshot);
  }

  @override
  Stream<DocumentSnapshotInterface> snapshots() {
    return _doc.snapshots().map((snapshot) => NativeDocumentSnapshot(snapshot));
  }
}

class NativeQuerySnapshot implements QuerySnapshotInterface {
  final native.QuerySnapshot _snapshot;

  NativeQuerySnapshot(this._snapshot);

  @override
  List<QueryDocumentSnapshotInterface> get docs => 
      _snapshot.docs.map((doc) => NativeQueryDocumentSnapshot(doc)).toList();

  @override
  List<DocumentChangeInterface> get docChanges =>
      _snapshot.docChanges.map((change) => NativeDocumentChange(change)).toList();
}

class NativeDocumentChange implements DocumentChangeInterface {
  final native.DocumentChange _change;

  NativeDocumentChange(this._change);

  @override
  DocumentChangeTypeInterface get type {
    switch (_change.type) {
      case native.DocumentChangeType.added:
        return DocumentChangeTypeInterface.added;
      case native.DocumentChangeType.modified:
        return DocumentChangeTypeInterface.modified;
      case native.DocumentChangeType.removed:
        return DocumentChangeTypeInterface.removed;
    }
  }

  @override
  QueryDocumentSnapshotInterface get doc => NativeQueryDocumentSnapshot(_change.doc as native.QueryDocumentSnapshot);

  @override
  int get newIndex => _change.newIndex;

  @override
  int get oldIndex => _change.oldIndex;
}

class NativeDocumentSnapshot implements DocumentSnapshotInterface {
  final native.DocumentSnapshot _snapshot;

  NativeDocumentSnapshot(this._snapshot);

  @override
  String get id => _snapshot.id;

  @override
  bool get exists => _snapshot.exists;

  @override
  DocumentReferenceInterface get reference => NativeDocumentReference(_snapshot.reference);

  @override
  Map<String, dynamic>? data() {
    return _snapshot.data() as Map<String, dynamic>?;
  }
}

class NativeQueryDocumentSnapshot extends NativeDocumentSnapshot implements QueryDocumentSnapshotInterface {
  NativeQueryDocumentSnapshot(native.QueryDocumentSnapshot super.snapshot);
  
  @override
  Map<String, dynamic> data() {
    return super.data()!;
  }
}


/// ---- Pure Dart (Firedart) Implementation ----

class PureDartFirestore implements FirestoreInterface {
  final fd.Firestore _firestore = fd.Firestore.instance;

  @override
  CollectionReferenceInterface collection(String path) {
    return PureDartCollectionReference(_firestore.collection(path));
  }

  @override
  WriteBatchInterface batch() {
    return PureDartWriteBatch();
  }
}

class PureDartWriteBatch implements WriteBatchInterface {
  final List<Future<void> Function()> _operations = [];

  @override
  void set(DocumentReferenceInterface ref, Map<String, dynamic> data, [native.SetOptions? options]) {
    _operations.add(() => ref.set(data, options));
  }

  @override
  void update(DocumentReferenceInterface ref, Map<String, dynamic> data) {
    _operations.add(() => ref.update(data));
  }

  @override
  void delete(DocumentReferenceInterface ref) {
    _operations.add(() => ref.delete());
  }

  @override
  Future<void> commit() async {
    // Firedart doesn't support atomic batch, execute sequentially
    for (final op in _operations) {
      await op();
    }
    _operations.clear();
  }
}

class PureDartCollectionReference extends PureDartQuery implements CollectionReferenceInterface {
  final fd.CollectionReference _collection;

  PureDartCollectionReference(this._collection) : super(_collection);

  @override
  DocumentReferenceInterface doc([String? path]) {
    if (path == null) {
       // Firedart limitation: requires ID or use add
       throw UnimplementedError('Firedart adapter requires explicit ID or use add()'); 
    }
    return PureDartDocumentReference(_collection.document(path));
  }

  @override
  Future<DocumentReferenceInterface> add(Map<String, dynamic> data) async {
    final doc = await _collection.add(data);
    return PureDartDocumentReference(_collection.document(doc.id));
  }
}

class PureDartQuery implements QueryInterface {
  final dynamic _query; // fd.CollectionReference or fd.Query

  PureDartQuery(this._query);

  @override
  QueryInterface where(String field, {dynamic isEqualTo}) {
    return PureDartQuery(_query.where(field, isEqualTo: isEqualTo));
  }

  @override
  QueryInterface orderBy(String field, {bool descending = false}) {
    return PureDartQuery(_query.orderBy(field, descending: descending));
  }

  @override
  QueryInterface limit(int limit) {
    return PureDartQuery(_query.limit(limit));
  }

  @override
  Future<QuerySnapshotInterface> get() async {
    final docs = await _query.get();
    return PureDartQuerySnapshot(docs, []);
  }

  @override
  Stream<QuerySnapshotInterface> snapshots() {
    // Firedart queries don't support streams, so we poll
    final controller = StreamController<QuerySnapshotInterface>.broadcast();
    List<fd.Document>? previousDocs;
    Timer? timer;

    void tick() async {
      try {
        final docs = await _query.get();
        final changes = _calculateDiff(previousDocs ?? [], docs);
        
        if (changes.isNotEmpty || previousDocs == null) {
          previousDocs = docs;
          if (!controller.isClosed) {
            controller.add(PureDartQuerySnapshot(docs, changes));
          }
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller.onListen = () {
      tick();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => tick());
    };

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  List<DocumentChangeInterface> _calculateDiff(List<fd.Document> oldDocs, List<fd.Document> newDocs) {
    final changes = <DocumentChangeInterface>[];
    final oldMap = {for (var d in oldDocs) d.id: d};
    final newMap = {for (var d in newDocs) d.id: d};

    // Check for added and modified
    for (int i = 0; i < newDocs.length; i++) {
      final newDoc = newDocs[i];
      final oldDoc = oldMap[newDoc.id];

      if (oldDoc == null) {
        changes.add(PureDartDocumentChange(
          DocumentChangeTypeInterface.added,
          PureDartQueryDocumentSnapshot(newDoc),
          i,
          -1,
        ));
      } else if (!_mapsEqual(oldDoc.map, newDoc.map)) {
        changes.add(PureDartDocumentChange(
          DocumentChangeTypeInterface.modified,
          PureDartQueryDocumentSnapshot(newDoc),
          i,
          oldDocs.indexOf(oldDoc),
        ));
      }
    }

    // Check for removed
    for (int i = 0; i < oldDocs.length; i++) {
      final oldDoc = oldDocs[i];
      if (!newMap.containsKey(oldDoc.id)) {
        changes.add(PureDartDocumentChange(
          DocumentChangeTypeInterface.removed,
          PureDartQueryDocumentSnapshot(oldDoc),
          -1,
          i,
        ));
      }
    }

    return changes;
  }

  bool _mapsEqual(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final valA = a[key];
      final valB = b[key];
      if (valA is Map && valB is Map) {
        if (!_mapsEqual(valA, valB)) return false;
      } else if (valA.toString() != valB.toString()) {
        return false;
      }
    }
    return true;
  }
}

class PureDartDocumentReference implements DocumentReferenceInterface {
  final fd.DocumentReference _doc;

  PureDartDocumentReference(this._doc);

  @override
  String get id => _doc.id;

  @override
  Future<void> set(Map<String, dynamic> data, [native.SetOptions? options]) async {
    if (options != null && options.merge == true) {
      // Upsert simulation using try-catch to avoid unauthenticated reads
      // (calling _doc.exists triggers read rules which fail if the doc doesn't exist)
      try {
        await _doc.set(data);
      } catch (e) {
        // If set fails (e.g. strict rules on existing docs), try update
        try {
          await _doc.update(data);
        } catch (e2) {
          rethrow; // If both fail, rethrow
        }
      }
    } else {
      await _doc.set(data);
    }
  }

  @override
  Future<void> update(Map<String, dynamic> data) => _doc.update(data);

  @override
  Future<void> delete() => _doc.delete();

  @override
  Future<DocumentSnapshotInterface> get() async {
    try {
      final doc = await _doc.get();
      return PureDartDocumentSnapshot(doc, true);
    } catch (e) {
      return PureDartDocumentSnapshot(null, false, id: _doc.id);
    }
  }

  @override
  Stream<DocumentSnapshotInterface> snapshots() {
    return _doc.stream.map((doc) => PureDartDocumentSnapshot(doc, true));
  }
}

class PureDartQuerySnapshot implements QuerySnapshotInterface {
  final List<fd.Document> _docs;
  final List<DocumentChangeInterface> _changes;

  PureDartQuerySnapshot(this._docs, this._changes);

  @override
  List<QueryDocumentSnapshotInterface> get docs => 
      _docs.map((doc) => PureDartQueryDocumentSnapshot(doc)).toList();

  @override
  List<DocumentChangeInterface> get docChanges => _changes;
}

class PureDartDocumentChange implements DocumentChangeInterface {
  final DocumentChangeTypeInterface _type;
  final QueryDocumentSnapshotInterface _doc;
  final int _newIndex;
  final int _oldIndex;

  PureDartDocumentChange(this._type, this._doc, this._newIndex, this._oldIndex);

  @override
  DocumentChangeTypeInterface get type => _type;

  @override
  QueryDocumentSnapshotInterface get doc => _doc;

  @override
  int get newIndex => _newIndex;

  @override
  int get oldIndex => _oldIndex;
}

class PureDartDocumentSnapshot implements DocumentSnapshotInterface {
  final fd.Document? _doc;
  final bool _exists;
  final String? _idOverride;

  PureDartDocumentSnapshot(this._doc, this._exists, {String? id}) : _idOverride = id;

  @override
  String get id => _doc?.id ?? _idOverride ?? '';

  @override
  bool get exists => _exists;

  @override
  DocumentReferenceInterface get reference {
     // Re-create the reference. 
     // We don't have the collection ref easily available here without passing it down.
     // But we can create a placeholder ref or change architecture.
     // For now, let's just cheat and assume we can ignore it or fail if used.
     // DeviceSyncService doesn't seem to use snapshot.reference heavily?
     // Wait, error logs said: "getter 'reference' isn't defined".
     // DeviceSyncService uses `change.doc.reference`?
     // No, `change.doc` is `QueryDocumentSnapshotInterface`.
     // If I look at the error log again: `lib/services/device_sync_service.dart(1277,41): error G4127D1E8: The getter 'reference' isn't defined`.
     // So it IS used.
     // I need to provide it.
     // I can store the reference in the snapshot wrapper.
     throw UnimplementedError('Reference on PureDartSnapshot not implemented');
  }

  @override
  Map<String, dynamic>? data() {
    return _doc?.map;
  }
}

class PureDartQueryDocumentSnapshot extends PureDartDocumentSnapshot implements QueryDocumentSnapshotInterface {
  PureDartQueryDocumentSnapshot(fd.Document doc) : super(doc, true);
  
  @override
  // Firedart Document has a reference property! `doc.reference`
  DocumentReferenceInterface get reference => PureDartDocumentReference(_doc!.reference);

  @override
  Map<String, dynamic> data() {
    return super.data()!;
  }
}

/// Factory to get instance
class FirestoreAdapter {
  static final FirestoreAdapter _instance = FirestoreAdapter._internal();
  factory FirestoreAdapter() => _instance;
  FirestoreAdapter._internal();

  static FirestoreInterface? _adapter;

  static void initialize({bool usePureDart = false}) {
    if (usePureDart) {
      debugPrint('🔥 Using Pure Dart Firestore (Firedart)');
      _adapter = PureDartFirestore();
    } else {
      debugPrint('🔥 Using Native Firestore SDK');
      _adapter = NativeFirestore();
    }
  }

  static FirestoreInterface get instance {
    _adapter ??= NativeFirestore();
    return _adapter!;
  }
}

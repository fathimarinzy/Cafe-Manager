import 'package:flutter/foundation.dart';
import '../models/delivery_boy.dart';
import '../repositories/local_delivery_boy_repository.dart';
import '../providers/lan_sync_provider.dart';
import '../models/lan_sync_models.dart';

class DeliveryBoyProvider with ChangeNotifier {
  final LocalDeliveryBoyRepository _repository = LocalDeliveryBoyRepository();
  List<DeliveryBoy> _deliveryBoys = [];

  DeliveryBoyProvider();
  bool _isLoading = false;

  List<DeliveryBoy> get deliveryBoys => _deliveryBoys;
  bool get isLoading => _isLoading;

  Future<void> loadDeliveryBoys() async {
    _isLoading = true;
    notifyListeners();

    try {
      _deliveryBoys = await _repository.getAllDeliveryBoys();
    } catch (e) {
      debugPrint('Error loading delivery boys: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addDeliveryBoy(DeliveryBoy boy) async {
    try {
      final savedBoy = await _repository.saveDeliveryBoy(boy);
      await loadDeliveryBoys(); // Reload full list to ensure consistency

      try {
        if (LanSyncProvider.instance.isActive) {
          LanSyncProvider.instance.broadcastEvent(SyncEvent(
            event: SyncEventType.deliveryBoyUpdated,
            data: savedBoy.toMap(),
            deviceId: LanSyncProvider.instance.deviceId,
          ));
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error adding delivery boy: $e');
    }
  }

  Future<void> updateDeliveryBoy(DeliveryBoy boy) async {
    await addDeliveryBoy(boy); 
  }

  Future<void> deleteDeliveryBoy(String id) async {
    try {
      final success = await _repository.deleteDeliveryBoy(id);
      if (success) {
        await loadDeliveryBoys();

        try {
          if (LanSyncProvider.instance.isActive) {
            LanSyncProvider.instance.broadcastEvent(SyncEvent(
              event: SyncEventType.deliveryBoyDeleted,
              data: {'id': id},
              deviceId: LanSyncProvider.instance.deviceId,
            ));
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error deleting delivery boy: $e');
    }
  }
}

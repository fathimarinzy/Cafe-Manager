import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../repositories/local_order_repository.dart';

class DashboardOfflineIndicator extends StatefulWidget {
  const DashboardOfflineIndicator({super.key});

  @override
  State<DashboardOfflineIndicator> createState() => _DashboardOfflineIndicatorState();
}

class _DashboardOfflineIndicatorState extends State<DashboardOfflineIndicator> {
  bool _isOffline = false;
  int _pendingOrderCount = 0;
  final LocalOrderRepository _orderRepo = LocalOrderRepository();
  
  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    
    // Listen for connectivity changes
    ConnectivityService().connectivityStream.listen((isConnected) {
      setState(() {
        _isOffline = !isConnected;
      });
      
      if (_isOffline) {
        _updatePendingCount();
      }
    });
  }
  
  Future<void> _checkConnectivity() async {
    final isConnected = await ConnectivityService().checkConnection();
    setState(() {
      _isOffline = !isConnected;
    });
    
    if (_isOffline) {
      _updatePendingCount();
    }
  }
  
  Future<void> _updatePendingCount() async {
    final count = await _orderRepo.getUnsyncedOrderCount();
    setState(() {
      _pendingOrderCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) {
      return const SizedBox.shrink(); // Hide when online
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pendingOrderCount > 0
                      ? 'You have $_pendingOrderCount order${_pendingOrderCount == 1 ? '' : 's'} waiting to be synced'
                      : 'All changes will be synced when connection is restored',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              // Try to reconnect
              final isConnected = await ConnectivityService().checkConnection();
              if (isConnected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Connection restored! Syncing data...')),
                );
                setState(() {
                  _isOffline = false;
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Still offline. Please check your connection.')),
                );
                _updatePendingCount();
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Check'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
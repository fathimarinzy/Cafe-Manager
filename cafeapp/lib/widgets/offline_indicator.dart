import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../repositories/local_order_repository.dart';

class OfflineIndicator extends StatefulWidget {
  final Widget child;
  final bool showOfflineBanner;
  final Function? onRefresh;

  const OfflineIndicator({
    super.key,
    required this.child,
    this.showOfflineBanner = true,
    this.onRefresh,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  final ConnectivityService _connectivityService = ConnectivityService();
  final LocalOrderRepository _orderRepo = LocalOrderRepository();
  bool _isRefreshing = false;
  int _pendingOrderCount = 0;
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  Future<void> _initialize() async {
    // Load the saved connectivity status first
    await _connectivityService.loadSavedConnectionStatus();
    
    // Update pending count if we're offline
    if (!_connectivityService.isConnected) {
      _updatePendingCount();
    }
    
    // Listen for connectivity changes
    _connectivityService.connectivityStream.listen((isConnected) {
      if (!isConnected) {
        _updatePendingCount();
      }
      
      // If we came back online, trigger a refresh if provided
      if (isConnected && widget.onRefresh != null) {
        _performRefresh();
      }
      
      if (mounted) {
        setState(() {});
      }
    });
  }
  
  Future<void> _updatePendingCount() async {
    final count = await _orderRepo.getUnsyncedOrderCount();
    if (mounted) {
      setState(() {
        _pendingOrderCount = count;
      });
    }
  }
  
  Future<void> _performRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      }
      await _updatePendingCount();
    } catch (e) {
      debugPrint('Error refreshing: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current connection status
    final isConnected = _connectivityService.isConnected;
    
    if (isConnected) {
      // Online - just show the child
      return widget.child;
    } else {
      // Offline - show the child with an offline indicator
      return Stack(
        children: [
          widget.child,
          if (widget.showOfflineBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 4,
                // child: Container(
                //   color: Colors.red,
                //   padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       Row(
                //         children: [
                //           const Icon(
                //             Icons.cloud_off,
                //             color: Colors.white,
                //             size: 16,
                //           ),
                //           const SizedBox(width: 8),
                //           Text(
                //             _pendingOrderCount > 0 
                //                 ? 'Offline Mode - $_pendingOrderCount order${_pendingOrderCount == 1 ? '' : 's'} waiting to sync'
                //                 : 'Offline Mode - Changes will sync when connected',
                //             style: Theme.of(context).textTheme.bodySmall?.copyWith(
                //               color: Colors.white,
                //               fontWeight: FontWeight.bold,
                //             ),
                //           ),
                //         ],
                //       ),
                //       _isRefreshing
                //           ? const SizedBox(
                //               width: 16,
                //               height: 16,
                //               child: CircularProgressIndicator(
                //                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                //                 strokeWidth: 2,
                //               ),
                //             )
                //           : IconButton(
                //               icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                //               padding: EdgeInsets.zero,
                //               constraints: const BoxConstraints(
                //                 minWidth: 24,
                //                 minHeight: 24,
                //               ),
                //               onPressed: () async {
                //                 // Try to reconnect
                //                 ScaffoldMessenger.of(context).showSnackBar(
                //                   const SnackBar(
                //                     content: Text('Checking connection...'),
                //                     duration: Duration(seconds: 1),
                //                   ),
                //                 );
                                
                //                 final isNowConnected = await _connectivityService.checkConnection();
                //                 if (isNowConnected) {
                //                   if (mounted) {
                //                     ScaffoldMessenger.of(context).showSnackBar(
                //                       const SnackBar(content: Text('Connection restored! Syncing data...')),
                //                     );
                //                   }
                //                   _performRefresh();
                //                 } else {
                //                   if (mounted) {
                //                     ScaffoldMessenger.of(context).showSnackBar(
                //                       const SnackBar(content: Text('Still offline. Please check your connection.')),
                //                     );
                //                   }
                //                   _updatePendingCount();
                //                 }
                //               },
                //             ),
                //     ],
                //   ),
                // ),
              ),
            ),
        ],
      );
    }
  }
}
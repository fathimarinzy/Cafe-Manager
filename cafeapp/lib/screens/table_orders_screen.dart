import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_history_provider.dart';
import '../models/order_history.dart';
import '../models/order_item.dart';
import 'order_details_screen.dart';
import 'menu_screen.dart';
import '../providers/order_provider.dart';
import '../utils/app_localization.dart';

class TableOrdersScreen extends StatefulWidget {
  final int tableNumber;

  const TableOrdersScreen({super.key, required this.tableNumber});

  @override
  State<TableOrdersScreen> createState() => _TableOrdersScreenState();
}

class _TableOrdersScreenState extends State<TableOrdersScreen> {
  bool _isLoading = true;
  List<OrderHistory> _orders = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
      
      final tableInfo = 'Dining - Table ${widget.tableNumber}';
      
      await historyProvider.loadOrdersByTable(tableInfo);
      
      setState(() {
        _orders = historyProvider.orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '${'Failed to load orders'.tr()}: $e';
      });
    }
  }

  void _createNewOrder() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final serviceType = 'Dining - Table ${widget.tableNumber}';
    
    orderProvider.setCurrentOrderId(null);
    orderProvider.setCurrentServiceType(serviceType);
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuScreen(
          serviceType: serviceType,
        ),
      ),
    );
    
    if (mounted) {
      _loadOrders();
    }
  }

  // Helper method to get translated status
  String _getTranslatedStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending'.tr();
      case 'completed':
        return 'Completed'.tr();
      case 'cancelled':
        return 'Cancelled'.tr();
      default:
        return status;
    }
  }

  // Helper method for more items text
  String getMoreItemsText(int count) {
    if (count == 1) {
      return '+ 1 ${'more item'.tr()}';
    } else {
      return '+ $count ${'more items'.tr()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text('${'Table'.tr()} ${widget.tableNumber} ${'Orders'.tr()}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _orders.isEmpty
                  ? _buildEmptyView()
                  : _buildOrdersList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOrders,
            child: Text('Try Again'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_restaurant, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '${'No orders found for Table'.tr()} ${widget.tableNumber}',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This table has no active or completed orders'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewOrder,
            icon: const Icon(Icons.add),
            label: Text('Create Order'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(OrderHistory order) {
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    
    Color statusColor = Colors.green;
    if (order.status.toLowerCase() == 'pending') {
      statusColor = Colors.orange;
    } else if (order.status.toLowerCase() == 'cancelled') {
      statusColor = Colors.red;
    }

    final bool isActive = order.status.toLowerCase() == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive 
            ? BorderSide(color: Colors.blue.shade400, width: 2) 
            : BorderSide.none,
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailsScreen(orderId: order.id),
              settings: const RouteSettings(name: 'OrderDetailsScreen'),
            ),
          ).then((_) => _loadOrders());
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? Colors.blue.shade50 : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'Order'.tr()} #${order.orderNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.formattedDate} ${'at'.tr()} ${order.formattedTime}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isActive)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(51),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _getTranslatedStatus(order.status),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Items'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildOrderItems(order.items),
                ],
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total'.tr(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        currencyFormat.format(order.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isActive)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                        ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailsScreen(orderId: order.id),
                            ),
                          ).then((_) => _loadOrders());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: Text('View Details'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems(List<OrderItem> items) {
    final sortedItems = List<OrderItem>.from(items)
      ..sort((a, b) => a.name.compareTo(b.name));
      
    final displayItems = sortedItems.length <= 3 
      ? sortedItems 
      : sortedItems.sublist(0, 3);
      
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.quantity.toString(),
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (item.kitchenNote.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${'Note'.tr()}: ${item.kitchenNote}',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${item.price.toStringAsFixed(3)} × ${item.quantity}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        )),
        
        if (items.length > 3) 
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              getMoreItemsText(items.length - 3),
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
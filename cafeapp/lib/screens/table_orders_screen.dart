import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_history_provider.dart';
import '../models/order_history.dart';
import '../models/order_item.dart';
import 'order_details_screen.dart';
import 'menu_screen.dart';
import '../providers/order_provider.dart';

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
      
      // Generate the table info string in the correct format for searching
      final tableInfo = 'Dining - Table ${widget.tableNumber}';
      
      await historyProvider.loadOrdersByTable(tableInfo);
      
      setState(() {
        _orders = historyProvider.orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load orders: $e';
      });
    }
  }

  // Find active (pending) orders for this table
  // OrderHistory? _getActiveOrder() {
  //   // Look for pending orders first
  //   for (var order in _orders) {
  //     if (order.status.toLowerCase() == 'pending') {
  //       return order;
  //     }
  //   }
  //   return null;
  // }

  // Add to an existing order
  // void _addToExistingOrder(OrderHistory order) async {
  //   // Get the order provider to set the service type
  //   final orderProvider = Provider.of<OrderProvider>(context, listen: false);
  //   final serviceType = 'Dining - Table ${widget.tableNumber}';
    
  //   // We need to set both service type and current order ID
  //   orderProvider.setCurrentServiceType(serviceType);
  //   orderProvider.setCurrentOrderId(order.id);
    
  //   // Navigate to the menu screen to add items
  //   await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => MenuScreen(
  //         serviceType: serviceType,
  //         existingOrderId: order.id,
  //       ),
  //     ),
  //   );
    
  //   // Refresh orders when returning
  //   if (mounted) {
  //     _loadOrders();
  //   }
  // }

  // Create a new order when no active order exists
  void _createNewOrder() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final serviceType = 'Dining - Table ${widget.tableNumber}';
    
    // Clear any existing order ID
    orderProvider.setCurrentOrderId(null);
    orderProvider.setCurrentServiceType(serviceType);
    
    // Navigate to menu screen to create a new order
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuScreen(
          serviceType: serviceType,
        ),
      ),
    );
    
    // Refresh orders when returning
    if (mounted) {
      _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Find active order if any exists
    // final activeOrder = _getActiveOrder();
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text('Table ${widget.tableNumber} Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   onPressed: _loadOrders,
          //   tooltip: 'Refresh',
          // ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _orders.isEmpty
                  ? _buildEmptyView()
                  : _buildOrdersList(),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () {
      //     if (activeOrder != null) {
      //       // Show dialog to choose between existing and new order
      //       _showOrderOptionsDialog(activeOrder);
      //     } else {
      //       // No active order, create a new one
      //       _createNewOrder();
      //     }
      //   },
      //   // backgroundColor: Colors.blue.shade700,
      //   // icon: const Icon(Icons.add_shopping_cart),
      //   label: const Text('Add Order'),
      // ),
    );
  }

  // Dialog to choose between adding to existing order or creating a new one
  // void _showOrderOptionsDialog(OrderHistory activeOrder) {
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: Text('Table ${widget.tableNumber}'),
  //       content: const Text('Would you like to add to the existing order or create a new one?'),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             Navigator.of(ctx).pop();
  //             _addToExistingOrder(activeOrder);
  //           },
  //           child: const Text('Add to Existing'),
  //           style: TextButton.styleFrom(
  //             foregroundColor: Colors.blue.shade700,
  //           ),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             Navigator.of(ctx).pop();
  //             _createNewOrder();
  //           },
  //           child: const Text('Create New'),
  //           style: TextButton.styleFrom(
  //             foregroundColor: Colors.green.shade700,
  //           ),
  //         ),
  //         TextButton(
  //           onPressed: () => Navigator.of(ctx).pop(),
  //           child: const Text('Cancel'),
  //           style: TextButton.styleFrom(
  //             foregroundColor: Colors.grey,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
            child: const Text('Try Again'),
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
            'No orders found for Table ${widget.tableNumber}',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This table has no active or completed orders',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewOrder,
            icon: const Icon(Icons.add),
            label: const Text('Create Order'),
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
    // Format currency
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    
    // Determine status color
    Color statusColor = Colors.green;
    if (order.status.toLowerCase() == 'pending') {
      statusColor = Colors.orange;
    } else if (order.status.toLowerCase() == 'cancelled') {
      statusColor = Colors.red;
    }

    // Check if this is an active order
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
            ),
          ).then((_) => _loadOrders()); // Refresh after returning
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header with status and time
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
                        'Order #${order.orderNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.formattedDate} at ${order.formattedTime}',
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
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          // child: IconButton(
                          //   icon: const Icon(Icons.add_circle),
                          //   color: Colors.blue.shade700,
                          //   tooltip: 'Add to this order',
                          //   onPressed: () => _addToExistingOrder(order),
                          // ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(51),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          order.status,
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
            
            // Order items
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildOrderItems(order.items),
                ],
              ),
            ),
            
            // Order total and view details button
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
                      const Text(
                        'Total',
                        style: TextStyle(
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
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          // child: OutlinedButton.icon(
                          //   onPressed: () => _addToExistingOrder(order),
                          //   icon: const Icon(Icons.add),
                          //   label: const Text('Add More'),
                          //   style: OutlinedButton.styleFrom(
                          //     foregroundColor: Colors.blue.shade700,
                          //     side: BorderSide(color: Colors.blue.shade300),
                          //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          //   ),
                          // ),
                        ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailsScreen(orderId: order.id),
                            ),
                          ).then((_) => _loadOrders()); // Refresh after returning
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Text('View Details'),
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
    // Sort items by name for better organization
    final sortedItems = List<OrderItem>.from(items)
      ..sort((a, b) => a.name.compareTo(b.name));
      
    // Show at most 3 items in the card, with a message if there are more
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
                          'Note: ${item.kitchenNote}',
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
        
        // Show a message if there are more items
        if (items.length > 3) 
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+ ${items.length - 3} more item${items.length - 3 > 1 ? 's' : ''}',
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
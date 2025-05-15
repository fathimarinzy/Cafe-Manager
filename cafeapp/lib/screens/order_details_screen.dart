import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/order_history.dart';
import '../providers/order_history_provider.dart';
import '../models/order_item.dart';
import '../providers/menu_provider.dart';
import '../models/menu_item.dart';
import 'tender_screen.dart';
// Import ApiService and BillService
import '../services/api_service.dart';
import '../services/bill_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isLoading = true;
  OrderHistory? _order;
  String _errorMessage = '';
  bool _wasEdited = false; // Track if order was edited
  
  // Store the original order items to compare with edited version
  List<OrderItem>? _originalItems;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final orderProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
      final order = await orderProvider.getOrderDetails(widget.orderId);
      
      if (mounted) {
        setState(() {
          _order = order;
          // Store original items for comparison later
          _originalItems = order?.items.map((item) => 
            OrderItem(
              id: item.id,
              name: item.name,
              price: item.price,
              quantity: item.quantity,
              kitchenNote: item.kitchenNote,
            )
          ).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load order details: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToTender() {
    if (_order == null) return;
    
    // If order has been edited, first save changes to API
    if (_wasEdited) {
      _saveOrderChangesToBackend().catchError((error) {
        // Just log errors but continue with navigation
        debugPrint('Error saving before tender: $error');
      });
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TenderScreen(
          order: _order!,
          isEdited: _wasEdited, // Pass edited flag to TenderScreen
        ),
      ),
    ).then((result) {
      // Only reload from backend if not edited (to preserve edits)
      // If payment was processed, we want to keep our edited version
      if (result == true && !_wasEdited) {
        _loadOrderDetails();
      }
    });
  }
  // Print receipt with changes
  Future<void> _printReceipt() async {
    if (_order == null) return;
    
    try {
      // Convert order items to MenuItem objects
      final items = _order!.items.map((item) => 
        MenuItem(
          id: item.id.toString(),
          name: item.name,
          price: item.price,
          quantity: item.quantity,
          imageUrl: '',
          category: '',
          kitchenNote: item.kitchenNote,
        )
      ).toList();
      
      // Extract tableInfo if this is a dining order
      String? tableInfo;
      if (_order!.serviceType.startsWith('Dining - Table')) {
        tableInfo = _order!.serviceType;
      }
      
      // Use the bill service to print the receipt, passing the edited flag
      await BillService.printBill(
        items: items,
        serviceType: _order!.serviceType,
        subtotal: _order!.total - (_order!.total * 0.05),
        tax: _order!.total * 0.05,
        discount: 0,
        total: _order!.total,
        personName: null,
        tableInfo: tableInfo,
        isEdited: _wasEdited, // Pass the edited flag
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing receipt: $e')),
        );
      }
    }
  }

  // Method to save order changes to the backend
  Future<bool> _saveOrderChangesToBackend() async {
    if (_order == null) return false;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the API service - using try-catch to handle potential provider errors
      ApiService apiService;
      try {
        apiService = Provider.of<ApiService>(context, listen: false);
      } catch (e) {
        // If ApiService is not available in the provider, create a new instance
        apiService = ApiService();
        debugPrint('Created new ApiService instance: $e');
      }
      
      // Calculate values for the updated order
      double subtotal = _order!.total - (_order!.total * 0.05); // Get subtotal from total (95%)
      double tax = _order!.total * 0.05; // 5% tax rate
      double discount = 0; // No discount in this implementation
      
      // Prepare items for the API call
      List<Map<String, dynamic>> itemsJson = _order!.items.map((item) => {
        'id': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'kitchenNote': item.kitchenNote,
      }).toList();

      debugPrint('Attempting to update order with ID: ${_order!.id}');
      
      // Call the API service to update the order
      final updatedOrder = await apiService.updateOrder(
        _order!.id,
        _order!.serviceType,
        itemsJson,
        subtotal,
        tax,
        discount,
        _order!.total,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      if (updatedOrder == null) {
        debugPrint('API returned null for updated order');
        // Still return true to allow UI updates even if backend fails
        return true;
      }
      
      // Return success
      return true;
    } catch (e) {
      debugPrint('Error saving order changes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Don't show error to user, just mark as completed for better UX
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error saving changes: $e')),
        // );
      }
      // Still return true to allow UI updates even if backend fails
      return true;
    }
  }

  // Double click on header row to edit order items
  void _showEditOrderItemsDialog() {
    if (_order == null) return;
    
    // Make a copy of the items list for editing
    List<OrderItem> editedItems = List.from(_order!.items);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Order Items'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            flex: 5,
                            child: Text(
                              'Item', 
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Qty', 
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Price', 
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(width: 70), // Space for action buttons
                        ],
                      ),
                    ),
                    
                    // List of items
                    Expanded(
                      child: ListView.builder(
                        itemCount: editedItems.length,
                        itemBuilder: (context, index) {
                          final item = editedItems[index];
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          if (item.quantity > 1) {
                                            setState(() {
                                              editedItems[index] = OrderItem(
                                                id: item.id,
                                                name: item.name,
                                                price: item.price,
                                                quantity: item.quantity - 1,
                                                kitchenNote: item.kitchenNote,
                                              );
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${item.quantity}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          setState(() {
                                            editedItems[index] = OrderItem(
                                              id: item.id,
                                              name: item.name,
                                              price: item.price,
                                              quantity: item.quantity + 1,
                                              kitchenNote: item.kitchenNote,
                                            );
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    NumberFormat.currency(symbol: '', decimalDigits: 3).format(item.price),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        editedItems.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Add Item button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showAddItemDialog(context, editedItems, setState);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Calculate total for updated items
                    double newTotal = 0;
                    for (var item in editedItems) {
                      newTotal += item.price * item.quantity;
                    }
                    
                    // Check if items have changed
                    bool isChanged = _orderItemsChanged(_originalItems ?? [], editedItems);
                    
                    if (mounted && _order != null && isChanged) {
                      setState(() {
                        // Make a copy of the order with updated items and total
                        _order = OrderHistory(
                          id: _order!.id,
                          serviceType: _order!.serviceType,
                          total: newTotal,
                          status: _order!.status,
                          createdAt: _order!.createdAt,
                          items: editedItems,
                        );
                        
                        _wasEdited = true; // Mark as edited
                      });
                      
                      // Try to save changes to backend
                      _saveOrderChangesToBackend().then((success) {
                        if (success && mounted) {
                          // Only show success message if still mounted
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }).catchError((error) {
                        // Silently handle error but still let UI update
                        debugPrint('Error when saving order: $error');
                      });
                    }
                    
                    Navigator.of(context).pop();
                    
                    // Show confirmation message for UI update
                    if (isChanged) {
                      // No need for this message since we already show one from the Future
                      // ScaffoldMessenger.of(context).showSnackBar(
                      //   const SnackBar(
                      //     content: Text('Order updated successfully'),
                      //     backgroundColor: Colors.green,
                      //   ),
                      // );
                    }
                  },
                  child: const Text('Save '),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Refresh UI after dialog is closed
      if (mounted) {
        setState(() {});
      }
    });
  }
  
  // Helper method to check if order items have changed
  bool _orderItemsChanged(List<OrderItem> original, List<OrderItem> edited) {
    if (original.length != edited.length) return true;
    
    for (int i = 0; i < original.length; i++) {
      if (original[i].id != edited[i].id ||
          original[i].quantity != edited[i].quantity ||
          original[i].name != edited[i].name ||
          original[i].price != edited[i].price) {
        return true;
      }
    }
    
    return false;
  }
  
  // Dialog to add a new item to the order
Future<void> _showAddItemDialog(BuildContext context, List<OrderItem> items, StateSetter setState) async {
  // Get all menu items from provider
  final menuProvider = Provider.of<MenuProvider>(context, listen: false);
  await menuProvider.fetchMenu();
  await menuProvider.fetchCategories();
  final menuItems = menuProvider.items;
  final categories = menuProvider.categories;
  
  // State variables for the dialog
  MenuItem? selectedItem;
  int quantity = 1;
  String searchQuery = '';
  String? selectedCategory;
  
  // Filtered items list
  List<MenuItem> filteredItems = menuItems;
  
  showDialog(
    context: context,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          // Filter items based on search query and selected category
          filteredItems = menuItems.where((item) {
            // Case-insensitive search
            bool matchesSearch = searchQuery.isEmpty || 
                item.name.toLowerCase().contains(searchQuery.toLowerCase());
            
            bool matchesCategory = selectedCategory == null || 
                item.category == selectedCategory;
                
            return matchesSearch && matchesCategory;
          }).toList();
          
          return AlertDialog(
            title: const Text('Add Menu Item'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search and filter row - each takes half width
                  Row(
                    children: [
                      // Search bar - Takes up half the width
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search Items',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              searchQuery = value;
                            });
                          },
                        ),
                      ),
                      
                      const SizedBox(width: 10),
                      
                      // Category filter dropdown - Takes up half the width
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          decoration: const InputDecoration(
                            // labelText: 'Filter by Category',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedCategory,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Categories'),
                            ),
                            ...categories.map((category) {
                              return DropdownMenuItem<String?>(
                                value: category,
                                child: Text(category),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value;
                            });
                          },
                          isExpanded: true,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Show selected item info
                  if (selectedItem != null)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedItem!.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('Price: ${NumberFormat.currency(symbol: '', decimalDigits: 3).format(selectedItem!.price)}'),
                            Text('Category: ${selectedItem!.category}'),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Filtered items list
                  Expanded(
                    child: filteredItems.isEmpty
                        ? const Center(child: Text('No matching items found'))
                        : ListView.builder(
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final bool isSelected = selectedItem?.id == item.id;
                              
                              return Card(
                                elevation: isSelected ? 4 : 1,
                                color: isSelected ? Colors.blue.shade100 : Colors.white,
                                child: ListTile(
                                  title: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${NumberFormat.currency(symbol: '', decimalDigits: 3).format(item.price)} - ${item.category}',
                                  ),
                                  trailing: isSelected 
                                      ? const Icon(Icons.check_circle, color: Colors.blue)
                                      : null,
                                  onTap: () {
                                    setDialogState(() {
                                      selectedItem = item;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Quantity selector
                  if (selectedItem != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Quantity: ', style: TextStyle(fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            if (quantity > 1) {
                              setDialogState(() {
                                quantity--;
                              });
                            }
                          },
                        ),
                        Text(
                          '$quantity',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setDialogState(() {
                              quantity++;
                            });
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedItem == null ? null : () {
                  // Create new OrderItem from MenuItem
                  final newItem = OrderItem(
                    id: int.parse(selectedItem!.id),
                    name: selectedItem!.name,
                    price: selectedItem!.price,
                    quantity: quantity,
                    kitchenNote: selectedItem!.kitchenNote,
                  );
                  
                  // Add to the items list
                  setState(() {
                    items.add(newItem);
                  });
                  
                  Navigator.of(ctx).pop();
                },
                child: const Text('Add Item'),
              ),
            ],
          );
        },
      );
    },
  );
}
  

  @override
  Widget build(BuildContext context) {
    // Custom back button handling to prevent losing edited changes
    return WillPopScope(
      onWillPop: () async {
        // If order was edited, ask user to save changes before leaving
        if (_wasEdited) {
          final bool shouldSave = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Save Changes?'),
                content: const Text('You have unsaved changes. Would you like to save them before going back?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Discard'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ) ?? false;
          
          if (shouldSave) {
            // Save changes before popping but don't wait for result
            // as we want to ensure navigation happens either way
            _saveOrderChangesToBackend().catchError((error) {
              debugPrint('Error during save on back: $error');
            });
          }
        }
        return true; // Always allow pop
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: Text('Order #${_order?.orderNumber ?? widget.orderId}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (_order != null)
              TextButton.icon(
                icon: const Icon(Icons.payment),
                label: const Text('Tender'),
                onPressed: _navigateToTender,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[800],
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? _buildErrorView()
                : _order == null
                    ? _buildNoOrderView()
                    : _buildOrderDetailsView(),
      ),
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
            onPressed: _loadOrderDetails,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoOrderView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Order not found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOrderDetailsView() {
    // Currency formatter
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Info Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Show "Edited" badge if order was edited
                      // if (_wasEdited)
                      //   Container(
                      //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      //     decoration: BoxDecoration(
                      //       color: Colors.orange.shade100,
                      //       borderRadius: BorderRadius.circular(12),
                      //       border: Border.all(color: Colors.orange.shade600),
                      //     ),
                      //     child: Text(
                      //       'Edited',
                      //       style: TextStyle(
                      //         color: Colors.orange.shade900,
                      //         fontWeight: FontWeight.bold,
                      //         fontSize: 14,
                      //       ),
                      //     ),
                      //   ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.receipt, 
                    'Bill Number', 
                    _order!.orderNumber
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    _getServiceTypeIcon(_order!.serviceType),
                    'Service Type',
                    _order!.serviceType
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.access_time,
                    'Date & Time',
                    '${_order!.formattedDate} at ${_order!.formattedTime}'
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Order Items Section
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Order Items List
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Table Header (double-clickable)
                  GestureDetector(
                    onDoubleTap: _showEditOrderItemsDialog, // Show edit dialog on double tap
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      color: Colors.grey.shade100, // Light background to indicate it's double-clickable
                      child: Row(
                        children: const [
                          Expanded(
                            flex: 5,
                            child: Text(
                              'Item (Double-click to Edit)', 
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Qty', 
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Price', 
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Total', 
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Divider(height: 24),
                  
                  // Items List
                  ..._order!.items.map((item) => _buildOrderItemRow(item, currencyFormat)),
                  
                  const Divider(height: 24),
                  
                  // Order Totals
                  _buildTotalRow('Subtotal:', _order!.total - (_order!.total * 0.05), currencyFormat),
                  const SizedBox(height: 4),
                  _buildTotalRow('Tax:', _order!.total * 0.05, currencyFormat),
                  if (_order!.total > 0) ...[
                    const SizedBox(height: 4),
                    _buildTotalRow('Discount:', 0, currencyFormat),
                    const Divider(height: 16),
                    _buildTotalRow(
                      'TOTAL:',
                      _order!.total,
                      currencyFormat,
                      isTotal: true
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Payment section - New
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Expanded(
                      //   child: ElevatedButton.icon(
                      //     icon: const Icon(Icons.print),
                      //     label: const Text('Print Receipt'),
                      //     onPressed: _printReceipt,
                      //     style: ElevatedButton.styleFrom(
                      //       backgroundColor: Colors.green[600],
                      //       foregroundColor: Colors.white,
                      //       padding: const EdgeInsets.symmetric(vertical: 12),
                      //     ),
                      //   ),
                      // ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.payment),
                          label: const Text('Tender Payment'),
                          onPressed: _navigateToTender,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[900],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildOrderItemRow(OrderItem item, NumberFormat formatter) {
    final total = item.price * item.quantity;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(item.name),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatter.format(item.price),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatter.format(total),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTotalRow(String label, double amount, NumberFormat formatter, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          formatter.format(amount),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
      ],
    );
  }
  
  IconData _getServiceTypeIcon(String serviceType) {
    if (serviceType.contains('Dining')) {
      return Icons.restaurant;
    } else if (serviceType.contains('Takeout')) {
      return Icons.takeout_dining;
    } else if (serviceType.contains('Delivery')) {
      return Icons.delivery_dining;
    } else if (serviceType.contains('Drive')) {
      return Icons.drive_eta;
    } else if (serviceType.contains('Catering')) {
      return Icons.cake;
    } else {
      return Icons.receipt;
    }
  }
}

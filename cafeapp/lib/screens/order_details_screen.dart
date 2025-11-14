import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/order_history.dart';
import '../providers/order_history_provider.dart';
import '../models/order_item.dart';
import '../providers/menu_provider.dart';
import '../models/menu_item.dart';
import 'tender_screen.dart';
import '../providers/settings_provider.dart';
import '../services/bill_service.dart';
import '../repositories/local_order_repository.dart';
import '../models/order.dart';
import '../utils/app_localization.dart';
import '../utils/service_type_utils.dart';
import '../repositories/local_person_repository.dart';
import '../models/person.dart';

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
  bool _wasEdited = false;
  List<OrderItem>? _originalItems;
  double _taxRate = 0.0;
  double _discountAmount = 0.0; 
  Person? _customer;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        setState(() {
          _taxRate = settingsProvider.taxRate;
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadOrderDetails();
      }
    });
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final orderProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
      final order = await orderProvider.getOrderDetails(widget.orderId);
      
      if (mounted && order != null) {
        Person? customer;
        if (order.customerId != null && order.customerId!.isNotEmpty) {
          try {
            final localPersonRepo = LocalPersonRepository();
            customer = await localPersonRepo.getPersonById(order.customerId!);
            debugPrint('Loaded customer: ${customer?.name ?? "NA"}');
          } catch (e) {
            debugPrint('Error loading customer: $e');
          }
        }
        
        double discount = 0.0;
        if (order.id > 0) {
          final localOrderRepo = LocalOrderRepository();
          try {
            final orderFromDb = await localOrderRepo.getOrderById(order.id);
            if (orderFromDb != null) {
              discount = orderFromDb.discount;
              debugPrint('Loaded discount from DB: $discount');
                // DEBUG: Print tax-exempt status of items
               for (var item in orderFromDb.items) {
              debugPrint('Item: ${item.name}, TaxExempt: ${item.taxExempt}');
            }
            }
          } catch (e) {
            debugPrint('Error getting order discount from DB: $e');
          }
        }
        
        setState(() {
          _order = order;
          _customer = customer;
          _discountAmount = discount;
          _originalItems = order.items.map((item) => 
            OrderItem(
              id: item.id,
              name: item.name,
              price: item.price,
              quantity: item.quantity,
              kitchenNote: item.kitchenNote,
              taxExempt: item.taxExempt,
            )
          ).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load order details'.tr();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToTender() {
    if (_order == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TenderScreen(
          order: _order!,
          isEdited: _wasEdited,
          taxRate: _taxRate,
          customer: _customer,
        ),
      ),
    ).then((result) {
      if (result == true && !_wasEdited && mounted) {
        _loadOrderDetails();
      }
    });
  }

  Future<bool> _saveOrderChangesToBackend() async {
    if (_order == null) return false;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // NEW: Calculate amounts with tax-exempt handling
      double taxableTotal = 0.0;
      double taxExemptTotal = 0.0;
      
      for (var item in _order!.items) {
        final itemTotal = item.price * item.quantity;
        if (item.taxExempt) {
          taxExemptTotal += itemTotal;
        } else {
          taxableTotal += itemTotal;
        }
      }
      
      double calculatedSubtotal;
      double calculatedTax;
      double calculatedTotal;
      
      if (settingsProvider.isVatInclusive) {
        // Inclusive VAT: extract tax only from taxable items
        final taxableAmount = taxableTotal / (1 + (settingsProvider.taxRate / 100));
        calculatedTax = taxableTotal - taxableAmount;
        calculatedSubtotal = taxableAmount + taxExemptTotal;
        calculatedTotal = (taxableTotal + taxExemptTotal) - _discountAmount;
      } else {
        // Exclusive VAT: add tax on top of taxable items only
        calculatedSubtotal = taxableTotal + taxExemptTotal;
        calculatedTax = taxableTotal * (settingsProvider.taxRate / 100);
        calculatedTotal = calculatedSubtotal + calculatedTax - _discountAmount;
      }

      final orderItems = _order!.items.map((item) => 
        OrderItem(
          id: item.id,
          name: item.name,
          price: item.price,
          quantity: item.quantity,
          kitchenNote: item.kitchenNote,
          taxExempt: item.taxExempt,
        )
      ).toList();

      // ✅ FIX: Get existing order to preserve payment details
      final localOrderRepo = LocalOrderRepository();
      final existingOrder = await localOrderRepo.getOrderById(_order!.id);
    
      
      final localOrder = Order(
        id: _order!.id,
        serviceType: _order!.serviceType,
        items: orderItems,
        subtotal: calculatedSubtotal,
        tax: calculatedTax,
        discount: _discountAmount,
        total: calculatedTotal,
        status: _order!.status,
        createdAt: _order!.createdAt.toIso8601String(),
        customerId: existingOrder?.customerId, // ✅ Preserve customer ID
        paymentMethod: existingOrder?.paymentMethod, // ✅ Preserve payment method
        cashAmount: existingOrder?.cashAmount, // ✅ Preserve cash amount
        bankAmount: existingOrder?.bankAmount, // ✅ Preserve bank amount
      );
      
      final updatedOrder = await localOrderRepo.saveOrder(localOrder);
      
      debugPrint('Order updated locally with VAT type: ${updatedOrder.id}');
      debugPrint('Taxable: $taxableTotal, Tax-Exempt: $taxExemptTotal');
      debugPrint('Subtotal: $calculatedSubtotal, Tax: $calculatedTax, Total: $calculatedTotal');
      debugPrint('Payment Method: ${updatedOrder.paymentMethod}');
      debugPrint('Cash Amount: ${updatedOrder.cashAmount}, Bank Amount: ${updatedOrder.bankAmount}');


      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_order != null) {
            _order = OrderHistory(
              id: _order!.id,
              serviceType: _order!.serviceType,
              total: calculatedTotal,
              status: _order!.status,
              createdAt: _order!.createdAt,
              items: _order!.items,
              customerId: existingOrder?.customerId,
            );
          }
        });
      }
      
      await _printKitchenReceipt();
      
      if (mounted) {
        final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
        historyProvider.loadOrders();
      }
      
      return updatedOrder.id != null;
    } catch (e) {
      debugPrint('Error saving order changes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _printKitchenReceipt() async {
    if (_order == null) return;
    
    try {
      final items = _order!.items.map((item) => 
        MenuItem(
          id: item.id.toString(),
          name: item.name,
          price: item.price,
          quantity: item.quantity,
          imageUrl: '',
          category: '',
          kitchenNote: item.kitchenNote,
          taxExempt: item.taxExempt,
        )
      ).toList();
      
      String? tableInfo;
      if (_order!.serviceType.startsWith('Dining - Table')) {
        tableInfo = _order!.serviceType;
      }
      
      final printed = await BillService.printKitchenOrderReceipt(
        items: items,
        serviceType: _order!.serviceType,
        tableInfo: tableInfo,
        orderNumber: _order!.orderNumber,
        isEdited: _wasEdited,
        originalItems: _originalItems, 
        context: mounted ? context : null,
      );
      
      if (!printed['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print kitchen receipt: ${printed['message']}'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error printing kitchen receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing kitchen receipt'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // double _calculateSubtotal(List<OrderItem> items) {
  //   return items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  // }

  void _showEditOrderItemsDialog() {
    if (_order == null) return;
    
    List<OrderItem> editedItems = List.from(_order!.items);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
            
            return AlertDialog(
              title: Text('Edit Order Items'.tr()),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * (isPortrait ? 0.9 : 0.7),
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: isPortrait ? 4 : 5,
                            child:  Text(
                              'Item'.tr(), 
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child:  Text(
                              'Qty'.tr(), 
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: isPortrait ? 2 : 3,
                            child:  Text(
                              'Price'.tr(), 
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(width: isPortrait ? 40 : 70),
                        ],
                      ),
                    ),
                    
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
                                  flex: isPortrait ? 4 : 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                          // NEW: Show tax-exempt indicator
                                          if (item.taxExempt)
                                            Container(
                                              margin: const EdgeInsets.only(left: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange[100],
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.orange[300]!),
                                              ),
                                              child: Text(
                                                'Tax Free'.tr(),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange[800],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
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
                                                taxExempt: item.taxExempt,
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
                                              taxExempt: item.taxExempt,
                                            );
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: isPortrait ? 2 : 3,
                                  child: Text(
                                    NumberFormat.currency(symbol: '', decimalDigits: 3).format(item.price),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(
                                  width: isPortrait ? 40 : 70,
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
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showAddItemDialog(context, editedItems, setState);
                        },
                        icon: const Icon(Icons.add),
                        label: Text('Add Item'.tr()),
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
                  child:  Text('Cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () async {
                    bool isChanged = _orderItemsChanged(_originalItems ?? [], editedItems);

                    if (!context.mounted || _order == null || !isChanged) {
                      if (context.mounted) Navigator.of(context).pop();
                      return;
                    }

                    // NEW: Calculate with tax-exempt handling
                    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                    
                    double taxableTotal = 0.0;
                    double taxExemptTotal = 0.0;
                    
                    for (var item in editedItems) {
                      final itemTotal = item.price * item.quantity;
                      if (item.taxExempt) {
                        taxExemptTotal += itemTotal;
                      } else {
                        taxableTotal += itemTotal;
                      }
                    }
                    
                    double newSubtotal;
                    double newTax;
                    double newTotal;
                    
                    if (settingsProvider.isVatInclusive) {
                      final taxableAmount = taxableTotal / (1 + (settingsProvider.taxRate / 100));
                      newTax = taxableTotal - taxableAmount;
                      newSubtotal = taxableAmount + taxExemptTotal;
                      newTotal = (taxableTotal + taxExemptTotal) - _discountAmount;
                    } else {
                      newSubtotal = taxableTotal + taxExemptTotal ;
                      newTax = taxableTotal * (settingsProvider.taxRate / 100);
                      newTotal = newSubtotal + newTax - _discountAmount;
                    }

                    setState(() {
                      _order = OrderHistory(
                        id: _order!.id,
                        serviceType: _order!.serviceType,
                        total: newTotal,
                        status: _order!.status,
                        createdAt: _order!.createdAt,
                        items: editedItems,
                        customerId: _order!.customerId,
                      );
                      _wasEdited = true;
                    });

                    bool success = false;
                    try {
                      success = await _saveOrderChangesToBackend();
                    } catch (error) {
                      debugPrint('Error when saving order: $error');
                    }

                    if (success && context.mounted) {
                      final historyProvider = Provider.of<OrderHistoryProvider>(context, listen: false);
                      historyProvider.loadOrders();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order updated successfully'.tr()),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }

                    if (context.mounted) Navigator.of(context).pop();
                  },                    
                  child:  Text('Save'.tr()),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }
 
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
  
  Future<void> _showAddItemDialog(BuildContext context, List<OrderItem> items, StateSetter setState) async {
    
    if (!context.mounted) return;

    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    await menuProvider.fetchMenu();
    await menuProvider.fetchCategories();

    if (!context.mounted) return;

    final menuItems = menuProvider.items;
    final categories = menuProvider.categories;
    
    MenuItem? selectedItem;
    int quantity = 1;
    String searchQuery = '';
    String? selectedCategory;
    
    List<MenuItem> filteredItems = menuItems;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            filteredItems = menuItems.where((item) {
              bool matchesSearch = searchQuery.isEmpty || 
                  item.name.toLowerCase().contains(searchQuery.toLowerCase());
              
              bool matchesCategory = selectedCategory == null || 
                  item.category == selectedCategory;
                  
              return matchesSearch && matchesCategory;
            }).toList();
            
            return AlertDialog(
              title: Text('Add Menu Item'.tr()),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration:  InputDecoration(
                              labelText: 'Search Items'.tr(),
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
                        
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            value: selectedCategory,
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Categories'.tr()),
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
                    
                    if (selectedItem != null)
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      selectedItem!.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  // NEW: Show tax-exempt indicator
                                  if (selectedItem!.taxExempt)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[100],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.orange[300]!),
                                      ),
                                      child: Text(
                                        'Tax Free'.tr(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[800],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text('${'Price'.tr()}: ${NumberFormat.currency(symbol: '', decimalDigits: 3).format(selectedItem!.price)}'),
                              Text('${'Category'.tr()}: ${selectedItem!.category.tr()}'),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(child: Text('No matching items found'.tr()))
                          : ListView.builder(
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final bool isSelected = selectedItem?.id == item.id;
                                
                                return Card(
                                  elevation: isSelected ? 4 : 1,
                                  color: isSelected ? Colors.blue.shade100 : Colors.white,
                                  child: ListTile(
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        // NEW: Show tax-exempt badge
                                        if (item.taxExempt)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[100],
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.orange[300]!),
                                            ),
                                            child: Text(
                                              'Tax Free'.tr(),
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[800],
                                              ),
                                            ),
                                          ),
                                      ],
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
                    
                    if (selectedItem != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Quantity:'.tr(), style: TextStyle(fontSize: 16)),
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
                  child:  Text('Cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: selectedItem == null ? null : () {
                    final newItem = OrderItem(
                      id: int.parse(selectedItem!.id),
                      name: selectedItem!.name,
                      price: selectedItem!.price,
                      quantity: quantity,
                      kitchenNote: selectedItem!.kitchenNote,
                      taxExempt: selectedItem!.taxExempt, // NEW: Include tax-exempt status
                    );
                    
                    setState(() {
                      items.add(newItem);
                    });
                    
                    Navigator.of(ctx).pop();
                  },
                  child:  Text('Add Item'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _reprintReceipt() async {
    if (_order == null) return;
    
    try {
      final items = _order!.items.map((item) => 
        MenuItem(
          id: item.id.toString(),
          name: item.name,
          price: item.price,
          quantity: item.quantity,
          imageUrl: '',
          category: '',
          kitchenNote: item.kitchenNote,
          taxExempt: item.taxExempt,
        )
      ).toList();
      
      String? tableInfo;
      if (_order!.serviceType.startsWith('Dining - Table')) {
        tableInfo = _order!.serviceType;
      }
      
      final result = await BillService.printKitchenOrderReceipt(
        items: items,
        serviceType: _order!.serviceType,
        tableInfo: tableInfo,
        orderNumber: _order!.orderNumber,
        context: mounted ? context : null,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'KOT receipt reprinted successfully'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to reprint KOT receipt'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error reprinting KOT receipt: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reprinting KOT receipt: ${e.toString()}'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async { 
        if (didPop) {
          return;
        }
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: Text('${'Order #'.tr()}${_order?.orderNumber ?? widget.orderId}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (_order != null)
              TextButton.icon(
                icon: const Icon(Icons.payment),
                label:  Text('Tender'.tr()),
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
            child: Text('Try Again'.tr()),
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
            'Order not found'.tr(),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Go Back'.tr()),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOrderDetailsView() {
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 3);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    // NEW: Calculate with tax-exempt handling
    double taxableTotal = 0.0;
    double taxExemptTotal = 0.0;
    
    for (var item in _order!.items) {
      final itemTotal = item.price * item.quantity;
      if (item.taxExempt) {
        taxExemptTotal += itemTotal;
      } else {
        taxableTotal += itemTotal;
      }
    }
    
    double subtotal;
    double tax;
    double total;
    
    if (settingsProvider.isVatInclusive) {
      final taxableAmount = taxableTotal / (1 + (settingsProvider.taxRate / 100));
      tax = taxableTotal - taxableAmount;
      subtotal = taxableAmount + taxExemptTotal;
      total = (taxableTotal + taxExemptTotal) - _discountAmount;
    } else {
      subtotal = taxableTotal + taxExemptTotal;
      tax = taxableTotal * (settingsProvider.taxRate / 100);
      total = subtotal + tax - _discountAmount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                     Text(
                        'Order Summary'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.receipt, 
                    'Bill Number'.tr(), 
                    _order!.orderNumber
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    _getServiceTypeIcon(_order!.serviceType),
                    'Service Type'.tr(),
                    _getTranslatedServiceType(_order!.serviceType)                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.person,
                    'Customer'.tr(),
                    _customer?.name ?? 'NA'.tr()
                  ),
                  const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.access_time,
                  'Date & Time'.tr(),
                  '${_order!.formattedDate} ${'at'.tr()} ${_order!.formattedTime}'
                ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Order Items'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onDoubleTap: _showEditOrderItemsDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      color: Colors.grey.shade100,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              'Items (Double-click to Edit)'.tr(), 
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Qty'.tr(), 
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                           Expanded(
                            flex: 3,
                            child: Text(
                              'Price'.tr(), 
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                    
                      
                           Expanded(
                            flex: 3,
                            child: Text(
                              'Total'.tr(), 
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Divider(height: 24),
                  
                  ..._order!.items.map((item) => _buildOrderItemRow(item, currencyFormat)),
                  
                  const Divider(height: 24),
                  
                  _buildTotalRow('Subtotal:'.tr(), subtotal, currencyFormat),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('Tax:'.tr()),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              settingsProvider.isVatInclusive ? 'Incl.' : 'Excl.',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(currencyFormat.format(tax)),
                    ],
                  ),
                  // NEW: Show tax-exempt total if any
                  // if (taxExemptTotal > 0) ...[
                  //   const SizedBox(height: 4),
                  //   Row(
                  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //     children: [
                  //       Text(
                  //         'Tax-Free Items:'.tr(),
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           color: Colors.orange[700],
                  //         ),
                  //       ),
                  //       Text(
                  //         currencyFormat.format(taxExemptTotal),
                  //         style: TextStyle(
                  //           fontSize: 12,
                  //           color: Colors.orange[700],
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ],
                  if (_discountAmount > 0 || total > 0) ...[
                    const SizedBox(height: 4),
                    if (_discountAmount > 0)
                    _buildTotalRow('Discount:'.tr(), _discountAmount, currencyFormat, isDiscount: true),
                    const Divider(height: 16),
                    _buildTotalRow(
                      'TOTAL:'.tr(),
                      total,
                      currencyFormat,
                      isTotal: true
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
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
                   Text(
                    'Payment'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.payment),
                          label: Text('Tender Payment'.tr()),
                          onPressed: _navigateToTender,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[900],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: Text('Reprint KOT'.tr()),
                          onPressed: _reprintReceipt,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[900],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
            child: Row(
              children: [
                Expanded(child: Text(item.name)),
                // NEW: Show tax-exempt indicator
                if (item.taxExempt)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Text(
                      'Tax Free'.tr(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
              ],
            ),
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
  
  Widget _buildTotalRow(String label, double amount, NumberFormat formatter, {bool isTotal = false, bool isDiscount = false}) {
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
  return ServiceTypeUtils.getIcon(serviceType);
}

String _getTranslatedServiceType(String serviceType) {
  return ServiceTypeUtils.getTranslated(serviceType);
}
}
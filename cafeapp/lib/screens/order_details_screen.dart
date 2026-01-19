import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../services/device_sync_service.dart';
import '../services/thermal_printer_service.dart';

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
  // Catering Details
  String? _eventDate;
  String? _eventTime;
  int? _eventGuestCount;
  String? _eventType;

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
      var order = await orderProvider.getOrderDetails(widget.orderId);
      
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
        String? eventDate;
        String? eventTime;
        int? eventGuestCount;
        String? eventType;

        if (order.id != null && order.id! > 0) {
          final localOrderRepo = LocalOrderRepository();
          try {
            final orderFromDb = await localOrderRepo.getOrderById(order.id!);
            if (orderFromDb != null) {
              discount = orderFromDb.discount;
              eventDate = orderFromDb.eventDate;
              eventTime = orderFromDb.eventTime;
              eventGuestCount = orderFromDb.eventGuestCount;
              eventType = orderFromDb.eventType;
              
              debugPrint('Loaded discount from DB: $discount');
              debugPrint('Loaded event info: $eventType, $eventDate');
              debugPrint('Loaded delivery charge from DB: ${orderFromDb.deliveryCharge}');
              
              // Prefer the fully populated DB order object
              order = orderFromDb;

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
          _order = OrderHistory.fromOrder(order!);
          _customer = customer;
          _discountAmount = discount;
          _eventDate = eventDate;
          _eventTime = eventTime;
          _eventGuestCount = eventGuestCount;
          _eventType = eventType;
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
    debugPrint('OrderDetails: Navigating to Tender. OrderID=${_order!.id}, Charge=${_order!.deliveryCharge}');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'TenderScreen'),
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

  Future<void> _printBillReceipt() async {
    if (_order == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Calculate amounts (Reuse logic from _buildOrderDetailsView)
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
      
      double deliveryCharge = _order!.deliveryCharge ?? 0.0;

      if (settingsProvider.isVatInclusive) {
        final taxableAmount = taxableTotal / (1 + (settingsProvider.taxRate / 100));
        tax = taxableTotal - taxableAmount;
        subtotal = taxableAmount + taxExemptTotal;
        total = (taxableTotal + taxExemptTotal + deliveryCharge) - _discountAmount;
      } else {
        subtotal = taxableTotal + taxExemptTotal;
        tax = taxableTotal * (settingsProvider.taxRate / 100);
        total = subtotal + tax + deliveryCharge - _discountAmount;
      }

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
      if (_order!.serviceType.toLowerCase().contains('dining') && _order!.serviceType.contains('-')) {
        tableInfo = _order!.serviceType.split('-').last.trim();
      }

      final success = await ThermalPrinterService.printOrderReceipt(
        serviceType: _order!.serviceType,
        items: items,
        subtotal: subtotal,
        tax: tax,
        discount: _discountAmount,
        total: total,
        personName: _customer?.name,
        tableInfo: tableInfo,
        orderNumber: _order!.orderNumber,
        taxRate: settingsProvider.taxRate,
        depositAmount: _order!.status == 'pending' ? _order!.depositAmount ?? 0.0 : null,
        deliveryCharge: deliveryCharge,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Receipt printed successfully'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to print receipt'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error printing bill receipt: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing receipt'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      
      double deliveryCharge = _order!.deliveryCharge ?? 0.0;

      if (settingsProvider.isVatInclusive) {
        // Inclusive VAT: extract tax only from taxable items
        final taxableAmount = taxableTotal / (1 + (settingsProvider.taxRate / 100));
        calculatedTax = taxableTotal - taxableAmount;
        calculatedSubtotal = taxableAmount + taxExemptTotal;
        calculatedTotal = (taxableTotal + taxExemptTotal + deliveryCharge) - _discountAmount;
      } else {
        // Exclusive VAT: add tax on top of taxable items only
        calculatedSubtotal = taxableTotal + taxExemptTotal;
        calculatedTax = taxableTotal * (settingsProvider.taxRate / 100);
        calculatedTotal = calculatedSubtotal + calculatedTax + deliveryCharge - _discountAmount;
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
      staffDeviceId: existingOrder?.staffDeviceId ?? '',
      serviceType: _order!.serviceType,
      items: orderItems,
      subtotal: calculatedSubtotal,
      tax: calculatedTax,
      discount: _discountAmount,
      total: calculatedTotal,
      status: _order!.status,
      createdAt: _order!.createdAt.toIso8601String(),
      customerId: existingOrder?.customerId,
      paymentMethod: existingOrder?.paymentMethod,
      cashAmount: existingOrder?.cashAmount,
      bankAmount: existingOrder?.bankAmount,
      staffOrderNumber: existingOrder?.staffOrderNumber, // Preserve staff order number
      mainOrderNumber: existingOrder?.mainOrderNumber, // Preserve main order number
      mainNumberAssigned: existingOrder?.mainNumberAssigned ?? false,
      deliveryAddress: existingOrder?.deliveryAddress,
      deliveryBoy: existingOrder?.deliveryBoy,
      deliveryCharge: existingOrder?.deliveryCharge,
    );
      
    final updatedOrder = await localOrderRepo.saveOrder(localOrder);

      // 🆕 SYNC THE EDITED ORDER TO FIRESTORE
    final prefs = await SharedPreferences.getInstance();
    final syncEnabled = prefs.getBool('device_sync_enabled') ?? false;
    final isMainDevice = prefs.getBool('is_main_device') ?? false;

    
     if (syncEnabled) {
      try {
        debugPrint('🔄 Syncing order edit from ${isMainDevice ? "MAIN" : "STAFF"} device...');
        final syncResult = await DeviceSyncService.syncOrderUpdate(updatedOrder);
        if (syncResult['success']) {
          debugPrint('✅ Order edit synced to Firebase');
        } else {
          debugPrint('⚠️ Order edit sync failed: ${syncResult['message']}');
        }
      } catch (e) {
        debugPrint('⚠️ Error syncing order edit: $e');
        // Don't fail the save if sync fails
      }
    }
    debugPrint('Order updated locally: ${updatedOrder.id}');
    debugPrint('Staff Device ID: ${updatedOrder.staffDeviceId}');
    debugPrint('Staff Order #: ${updatedOrder.staffOrderNumber}');
    debugPrint('Main Order #: ${updatedOrder.mainOrderNumber}');
    debugPrint('OrderDetails: Delivery Charge: ${updatedOrder.deliveryCharge}');

      debugPrint('Order updated locally with VAT type: ${updatedOrder.id}');
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
                    
                    double deliveryCharge = _order!.deliveryCharge ?? 0.0;

                    if (settingsProvider.isVatInclusive) {
                      final taxableAmount = taxableTotal / (1 + (settingsProvider.taxRate / 100));
                      newTax = taxableTotal - taxableAmount;
                      newSubtotal = taxableAmount + taxExemptTotal;
                      newTotal = (taxableTotal + taxExemptTotal + deliveryCharge) - _discountAmount;
                    } else {
                      newSubtotal = taxableTotal + taxExemptTotal ;
                      newTax = taxableTotal * (settingsProvider.taxRate / 100);
                      newTotal = newSubtotal + newTax + deliveryCharge - _discountAmount;
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
            if (_order != null) ...[
              TextButton.icon(
                icon: const Icon(Icons.print),
                label: Text('Print'.tr()),
                onPressed: _printBillReceipt,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[800],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.payment),
                label:  Text('Tender'.tr()),
                onPressed: _navigateToTender,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[800],
                ),
              ),
            ],
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
  
  // Show dialog to edit delivery details
  void _showEditDeliveryDetailsDialog() {
    if (_order == null) return;
    
    final addressController = TextEditingController(text: _order!.deliveryAddress ?? '');
    final chargeController = TextEditingController(text: (_order!.deliveryCharge ?? 0.0).toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Delivery Details'.tr()),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Delivery Address'.tr(),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter delivery address'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: chargeController,
                    decoration: InputDecoration(
                      labelText: 'Delivery Charge'.tr(),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter charge'.tr();
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid amount'.tr();
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newAddress = addressController.text;
                  final newCharge = double.parse(chargeController.text);
                  
                  Navigator.of(context).pop();
                  
                  setState(() {
                    _isLoading = true;
                  });
                  
                  try {
                    final provider = Provider.of<OrderHistoryProvider>(context, listen: false);
                    final success = await provider.updateOrderDeliveryDetails(
                      _order!.id,
                      newAddress,
                      _order!.deliveryBoy ?? '',
                      newCharge,
                    );
                    
                    if (success) {
                      await _loadOrderDetails(); // Reload to refresh UI
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Delivery details updated'.tr()),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                       if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update details'.tr()),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint('Error updating delivery details: $e');
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                }
              },
              child: Text('Save'.tr()),
            ),
          ],
        );
      },
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
    
    double deliveryCharge = _order!.deliveryCharge ?? 0.0;

    if (settingsProvider.isVatInclusive) {
      final taxableAmount = taxableTotal / (1 + (settingsProvider.taxRate / 100));
      tax = taxableTotal - taxableAmount;
      subtotal = taxableAmount + taxExemptTotal;
      total = (taxableTotal + taxExemptTotal + deliveryCharge) - _discountAmount;
    } else {
      subtotal = taxableTotal + taxExemptTotal;
      tax = taxableTotal * (settingsProvider.taxRate / 100);
      total = subtotal + tax + deliveryCharge - _discountAmount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_order!.serviceType.toLowerCase().contains('delivery')) ...[
              Card(
                elevation: 2,
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping, color: Colors.orange[800]),
                              const SizedBox(width: 8),
                              Text(
                                'Delivery Details'.tr(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.orange),
                            onPressed: _showEditDeliveryDetailsDialog,
                            tooltip: 'Edit Details'.tr(),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (_order!.deliveryAddress != null)
                        _buildInfoRow(Icons.location_on, 'Address'.tr(), _order!.deliveryAddress!),
                      const SizedBox(height: 8),
                      if (_order!.deliveryBoy != null)
                        _buildInfoRow(Icons.directions_bike, 'Delivery Boy'.tr(), _order!.deliveryBoy!),
                      const SizedBox(height: 8),
                      if (_order!.deliveryCharge != null)
                        _buildInfoRow(Icons.attach_money, 'Delivery Charge'.tr(), currencyFormat.format(_order!.deliveryCharge!)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
          ],

          // Dining Details Card (Blue)
          if (_order!.serviceType.toLowerCase().contains('dining')) ...[
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.table_restaurant, color: Colors.blue[800]),
                        const SizedBox(width: 8),
                        Text(
                          'Dining Details'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow(Icons.restaurant, 'Service Type'.tr(), 'Dine-In'.tr()),
                    const SizedBox(height: 8),
                    // Extract table info if present in string like "Dining - Table 5"
                    if (_order!.serviceType.contains('-')) 
                      _buildInfoRow(Icons.table_bar, 'Table'.tr(), _order!.serviceType.split('-').last.trim()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Takeout / Take Away Details Card (Green)
          if (_order!.serviceType.toLowerCase().contains('takeaway') || _order!.serviceType.toLowerCase().contains('takeout')) ...[
            Card(
              elevation: 2,
              color: Colors.green.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_bag, color: Colors.green[800]),
                        const SizedBox(width: 8),
                        Text(
                          'Takeout Details'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow(Icons.run_circle, 'Type'.tr(), 'Take Away'.tr()),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.timer, 'Status'.tr(), 'Ready for Pickup'.tr()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Online Order Details Card (Cyan)
          if (_order!.serviceType.toLowerCase().contains('online')) ...[
            Card(
              elevation: 2,
              color: Colors.cyan.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.public, color: Colors.cyan[800]),
                        const SizedBox(width: 8),
                        Text(
                          'Online Order'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyan[900],
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow(Icons.web, 'Source'.tr(), 'Web/App'.tr()),
                    const SizedBox(height: 8),
                    // Placeholder for potential online order ID or external reference
                     _buildInfoRow(Icons.confirmation_number, 'Ref #'.tr(), _order!.orderNumber.toString()), 
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Drive-Thru Details Card (Pink)
          if (_order!.serviceType.toLowerCase().contains('drive')) ...[
            Card(
              elevation: 2,
              color: Colors.pink.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions_car, color: Colors.pink[800]),
                        const SizedBox(width: 8),
                        Text(
                          'Drive-Thru'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink[900],
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow(Icons.car_repair, 'Service'.tr(), 'Drive-Through'.tr()),
                    const SizedBox(height: 8),
                    // Extract vehicle info if present in string like "Drive-Thru - KA01AB1234"
                    if (_order!.serviceType.contains('-'))
                      _buildInfoRow(Icons.directions_car, 'Vehicle No'.tr(), _order!.serviceType.split('-').last.trim())
                    else
                      _buildInfoRow(Icons.directions_car, 'Vehicle No'.tr(), 'Not Provided'.tr()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Catering Details Card
          if (_eventType != null && (_order!.serviceType.toLowerCase().contains('catering'))) ...[
            Card(
              elevation: 2,
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cake, color: Colors.amber[900]),
                        const SizedBox(width: 8),
                        Text(
                          'Event Details'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow(Icons.event_note, 'Event Type'.tr(), _eventType!),
                    const SizedBox(height: 8),
                    if (_eventDate != null)
                      _buildInfoRow(Icons.calendar_today, 'Date'.tr(), _eventDate!),
                    const SizedBox(height: 8),
                    if (_eventTime != null)
                      _buildInfoRow(Icons.access_time, 'Time'.tr(), _eventTime!),
                    const SizedBox(height: 8),
                    if (_eventGuestCount != null)
                      _buildInfoRow(Icons.people, 'Guests'.tr(), '$_eventGuestCount'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
                  if (_order!.serviceType.toLowerCase().contains('delivery')) ...[
                    const SizedBox(height: 4),
                    _buildTotalRow('Delivery Fee:'.tr(), deliveryCharge, currencyFormat),
                  ],
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
                    if ((_order!.depositAmount ?? 0.0) > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Advance Paid:'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          Text(
                            currencyFormat.format(_order!.depositAmount),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Balance Due:'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          Text(
                            currencyFormat.format(total - (_order!.depositAmount ?? 0.0)),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  Column(
                    children: [
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
                                minimumSize: const Size(double.infinity, 48), // Explicit height
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.print),
                              label: Text('Reprint KOT'.tr()),
                              onPressed: _reprintReceipt,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[700], // distinct color for secondary action
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
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
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
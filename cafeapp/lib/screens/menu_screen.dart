import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/menu_provider.dart';
import '../providers/order_provider.dart';
import '../models/menu_item.dart';
import '../screens/person_form_screen.dart';
import '../screens/search_person_screen.dart';
import '../screens/modifier_screen.dart';
import '../screens/table_management_screen.dart';
import '../screens/order_confirmation_screen.dart';
import '../screens/order_list_screen.dart';
import '../widgets/kitchen_note_dialog.dart';
import '../utils/app_localization.dart';
import '../providers/settings_provider.dart';
import '../screens/tender_screen.dart';
import '../models/order_history.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/person.dart';
import '../screens/printer_settings_screen.dart';
import '../services/thermal_printer_service.dart';


class MenuScreen extends StatefulWidget {
  final String serviceType;
  final Color serviceColor;
  final int? existingOrderId; // Add this parameter
  const MenuScreen({super.key, required this.serviceType,this.serviceColor = const Color(0xFF1565C0),this.existingOrderId,});

  @override
  MenuScreenState createState() => MenuScreenState();
}
// Helper function for light background colors
    Color getLightBackgroundColor(Color baseColor) {
      return baseColor.withAlpha(25);
    }

class MenuScreenState extends State<MenuScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
  String _selectedCategory = '';
  String _itemSearchQuery = '';
  String _currentTime = '';
  Timer? _timer;
  MenuItem? _selectedItem; // Track the currently selected item
  // Caching variables to reduce rebuilds
  List<MenuItem>? _cachedItems;
  String _lastCategory = '';
  String _lastSearchQuery = '';
  final Map<String, Uint8List> _imageCache = {};
  // Add these new variables for KOT printer functionality
  bool _isKotPrinterEnabled = true;
  bool _isCheckingKotPrinter = false;
   

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMenu();
    _updateTime();
    _loadKotPrinterSettings(); // Add this line

    
   // Set the current service type and order ID in OrderProvider
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    orderProvider.setCurrentServiceType(widget.serviceType);
     orderProvider.clearSelectedPerson();
    
    // If an existing order ID was provided
    if (widget.existingOrderId != null) {
      // Check if we need to load the items (they might have been loaded already)
      if (orderProvider.currentOrderId != widget.existingOrderId) {
        orderProvider.setCurrentOrderId(widget.existingOrderId);
        
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );
        
        // Load existing items into the cart
        await orderProvider.loadExistingOrderItems(widget.existingOrderId!);
        
        // Close the loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  });
}
   // Add this new method to load KOT printer settings
  Future<void> _loadKotPrinterSettings() async {
    try {
      final enabled = await ThermalPrinterService.isKotPrinterEnabled();
      setState(() {
        _isKotPrinterEnabled = enabled;
      });
    } catch (e) {
      debugPrint('Error loading KOT printer settings: $e');
    }
  }

  // Add this new method to save KOT printer settings
  Future<void> _saveKotPrinterSettings() async {
    try {
      await ThermalPrinterService.setKotPrinterEnabled(_isKotPrinterEnabled);
    } catch (e) {
      debugPrint('Error saving KOT printer settings: $e');
    }
  }

  // Add this new method to toggle KOT printer connection
  Future<void> _toggleKotPrinterConnection() async {
    setState(() {
      _isCheckingKotPrinter = true;
    });

    try {
      if (_isKotPrinterEnabled) {
        // Turn off KOT printer
        setState(() {
          _isKotPrinterEnabled = false;
        });
        await _saveKotPrinterSettings();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kitchen printer disabled'.tr()),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Turn on KOT printer and test connection
        final connected = await ThermalPrinterService.testKotConnection();
        
        if (connected) {
          setState(() {
            _isKotPrinterEnabled = true;
          });
          await _saveKotPrinterSettings();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Kitchen printer connected successfully'.tr()),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to connect to kitchen printer. Check settings.'.tr()),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Settings'.tr(),
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrinterSettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error toggling KOT printer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error with kitchen printer connection'.tr()),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    setState(() {
      _isCheckingKotPrinter = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh data when the app comes back to the foreground
    if (state == AppLifecycleState.resumed) {
      _loadMenu();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Function to update the current time every second
  void _updateTime() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateFormat('hh:mm a').format(DateTime.now());
        });
      } else {
        // Cancel timer if widget is no longer mounted
        timer.cancel();
      }
    });
  }
  
  // Get displayed items with caching for performance
  List<MenuItem> _getDisplayedItems(MenuProvider menuProvider) {
    // Only recalculate if category or search has changed
    if (_cachedItems != null && 
        _lastCategory == _selectedCategory && 
        _lastSearchQuery == _itemSearchQuery) {
      return _cachedItems!;
    }

    List<MenuItem> items;
    // First get items by category
    items = _selectedCategory.isNotEmpty
        ? menuProvider.getItemsByCategory(_selectedCategory)
        : menuProvider.items;

    // Then filter by search query
    if (_itemSearchQuery.isNotEmpty) {
      items = menuProvider.items.where((item) {
        return item.name.toLowerCase().contains(_itemSearchQuery.toLowerCase());
      }).toList();
    }

    // Update caching variables
    _lastCategory = _selectedCategory;
    _lastSearchQuery = _itemSearchQuery;
    _cachedItems = items;
    
    return items;
  }

  Future<void> _loadMenu() async {
  if (!mounted) return;
  
  // Only show loading indicator for first load
  final menuProvider = Provider.of<MenuProvider>(context, listen: false);
  final bool isEmpty = menuProvider.items.isEmpty || menuProvider.categories.isEmpty;
  
  if (isEmpty) {
    setState(() {
      _isLoading = true;
      _cachedItems = null;
    });
  }
  
  try {
    // Use Future.wait to load menu and categories in parallel
    await Future.wait([
      menuProvider.fetchMenu(),
      menuProvider.fetchCategories()
    ]);
    
    if (mounted) {
      setState(() {
        // Only set the category if it's empty or no longer exists
        if (_selectedCategory.isEmpty || 
            !menuProvider.categories.contains(_selectedCategory)) {
          _selectedCategory = menuProvider.categories.isNotEmpty ? 
              menuProvider.categories.first : '';
        }
        _isLoading = false;
      });
    }
  } catch (error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to load menu. Please try again.')),
    );
    setState(() {
      _isLoading = false;
    });
  }
}
  
  // _showKitchenNoteDialog method 

  void _showKitchenNoteDialog(MenuItem? item) async {
  // Ensure we have a non-null item
  if (item == null) {
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('Please select an item first'.tr())),
    );
    return;
  }
  
  setState(() {
    _selectedItem = item; // Set the selected item
  });
  
  // Initialize with empty string if null
  String initialNote = item.kitchenNote.isEmpty ? '' : item.kitchenNote;
  
  final String? note = await showDialog<String>(
    context: context,
    builder: (context) => KitchenNoteDialog(
      initialNote: initialNote,
    ),
  );
  
  // If dialog was not canceled and we have a note
  if (note != null) {
    setState(() {
      // Create a copy of the item with the new note
      MenuItem updatedItem = item.copyWith(kitchenNote: note);
      
      // Find the item in the cart and update it
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final cartItems = orderProvider.cartItems;
      
      bool itemFound = false;
      for (int i = 0; i < cartItems.length; i++) {
        if (cartItems[i].id == item.id) {
          // Update the kitchen note for this item
          orderProvider.updateItemNote(item.id, note);
          itemFound = true;
          break;
        }
      }
      
      // If the item wasn't in the cart, add it with the note
      if (!itemFound) {
        orderProvider.addToCart(updatedItem);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Kitchen note added'.tr()),
          duration: Duration(seconds: 1),
        ),
      );
    });
  }
}

  @override
  Widget build(BuildContext context) {
    final menuProvider = Provider.of<MenuProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
     // Watch settings changes without creating an unused variable
    context.watch<SettingsProvider>();

      // When the tax rate changes in settings, update the orderProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      orderProvider.setContext(context);
      
      // Recalculate totals when tax rate changes
      final currentCart = orderProvider.cartItems;
      if (currentCart.isNotEmpty) {
        // Force a recalculation of totals by triggering a change
        // This is a hacky way to ensure totals are updated when tax rate changes
        for (var item in currentCart) {
          orderProvider.updateItemQuantity(item.id, item.quantity);
          break; // Just need to update one item to trigger recalculation
        }
      }
    });

    // Use the cached/memoized items list
    List<MenuItem> displayedItems = _getDisplayedItems(menuProvider);

    return PopScope(
      // Refresh when popping back to this screen
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          await _loadMenu();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.serviceType,
            style: const TextStyle(color: Colors.black),
          ),
          actions: [
             // Add Kitchen Printer Toggle Button
            IconButton(
              onPressed: _isCheckingKotPrinter ? null : _toggleKotPrinterConnection,
              icon: _isCheckingKotPrinter
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey.shade600,
                      ),
                    )
                  : Icon(
                      _isKotPrinterEnabled ? Icons.print : Icons.print_disabled,
                      color: _isKotPrinterEnabled ? Colors.blue.shade700 : Colors.blue.shade700,
                      size: 24,
                    ),
              tooltip: _isKotPrinterEnabled ? 'Kitchen Printer Connected'.tr() : 'Kitchen Printer Disconnected'.tr(),
            ),
            const SizedBox(width: 8),
 
            // Add Order List button to the left of time
            TextButton.icon(  
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderListScreen(serviceType: widget.serviceType,fromMenuScreen: true, ),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long, color: Colors.black, size: 20),
              label:  Text('Order List'.tr(), style: TextStyle(color: Colors.black, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            // Time display
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.black, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    _currentTime,
                    style: const TextStyle(color: Colors.black),
                  ),
                ],
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: Colors.grey.shade300,
              height: 1.0,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategorySidebar(menuProvider.categories),
                  Container(
                    width: 1.0,
                    color: Colors.grey.shade300,
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategoryHeader(),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _buildProductGrid(displayedItems, orderProvider),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1.0,
                    color: Colors.grey.shade300,
                  ),
                  _buildOrderPanel(orderProvider),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              _buildNavButton(Icons.arrow_back_ios, null, ''),
              // _buildNavButton(null, null, 'Discount'.tr()),
              // _buildNavButton(null, null, 'Sales hold list'),
              // _buildNavButton(null, null, 'Hold'),
              // _buildNavButton(null, null, 'Memo'),
              // _buildNavButton(null, null, 'Product'),
              _buildNavButton(null, null, 'Kitchen note'.tr()),
              _buildNavButton(null, null, 'Clear'.tr()),
              // _buildNavButton(null, null, 'Remove'.tr()),
              // _buildNavButton(null, null, 'Amount split'),
              // _buildNavButton(null, null, 'Item split'),
              _buildNavButton(null, null, 'Order List'.tr()),
              // _buildNavButton(null, null, 'Tables'),
              _buildNavButton(Icons.arrow_forward_ios, null, ''),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData? iconData, Color? iconColor, String text) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: TextButton(
          onPressed: () {
            if (text == 'Product'.tr()) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModifierScreen()
                ),
              ).then((_) {
                // Refresh when returning from ModifierScreen
                _loadMenu();
              });
            } else if (text == 'Clear'.tr()) {
              // Clear the current cart with visual feedback
              final orderProvider = Provider.of<OrderProvider>(context, listen: false);
              
              // Only show the confirmation if there are items in the cart
              if (orderProvider.cartItems.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title:  Text('Clear Order'.tr(),style: TextStyle(
                      fontSize: 18, // Smaller font size (default is usually 20-22)
                      fontWeight: FontWeight.bold,
                    ),
                    ),
                    content:  Text('Are you sure you want to clear all items from this order?'.tr()),
                    actions: [
                      TextButton(
                        child:  Text('Cancel'.tr()),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      TextButton(
                        child:  Text('Clear'.tr(), style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          orderProvider.clearCart();
                          Navigator.of(ctx).pop();
                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(
                              content: Text('Order cleared successfully'.tr()),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              } else {
                // If the cart is already empty, just show a message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order is already empty'.tr()),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            } else if (text == 'Tables'.tr() ) {
              // Handle Tables navigation
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TableManagementScreen()
                ),
              ).then((_) {
                // Refresh when returning from TableManagementScreen
                _loadMenu();
              });
            }else if (text == 'Order List'.tr()) {
              // Navigate to OrderListScreen with current service type
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderListScreen(serviceType: widget.serviceType, fromMenuScreen: true, ),
                ),
              );
            }else if (text == 'Kitchen note'.tr()) {
            // Show kitchen note dialog if an item is selected
            if (_selectedItem != null) {
              _showKitchenNoteDialog(_selectedItem!);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                  content: Text('Please select a menu item first'.tr()),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
            // Add other navigation cases as needed
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: iconData != null
              ? Icon(iconData, size: 16, color: iconColor ?? Colors.black)
              : Text(
                  text,
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }

  Widget _buildCategorySidebar(List<String> categories) {
    // Filter categories based on search (if needed)
    final filteredCategories = categories;
      // Get the light background color based on service type
    final lightBgColor = getLightBackgroundColor(widget.serviceColor);

    return Container(
      width: 250,
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Search field for menu items
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Menu...".tr(),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _itemSearchQuery = value; // Update item search query
                  _cachedItems = null; // Invalidate cache when search changes
                  if (value.isNotEmpty) {
                    _selectedCategory = '';
                  } else if (filteredCategories.isNotEmpty) {
                    // Reset to first category when search is cleared
                    _selectedCategory = filteredCategories.first;
                  }
                });
              },
            ),
          ),
          // Add a thin border line under the search bar
          Container(
            height: 1.0,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
          ),

          // Category header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [],
            ),
          ),
          // Category list
          Expanded(
            child: ListView.builder(
              itemCount: filteredCategories.length,
              itemBuilder: (ctx, index) {
                final category = filteredCategories[index];
                final isSelected = _selectedCategory == category;
                return Container(
                  key: ValueKey('category_$category'),
                  decoration: BoxDecoration(
                    color: isSelected ? lightBgColor : Colors.transparent,
                    border: Border(
                     left: BorderSide(
                        color: isSelected ? widget.serviceColor : Colors.transparent,
                        width: 5.0,
                      ),
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      category,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _cachedItems = null; // Invalidate cache when category changes
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        _selectedCategory.toUpperCase(),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<MenuItem> items, OrderProvider orderProvider) {
  return Container(
    color: Colors.grey.shade100,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: items.isEmpty 
          ? Center(child: Text('No items found in this category'.tr()))
          : GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 0.8,
          crossAxisSpacing: 13,
          mainAxisSpacing: 13,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, index) {
          final item = items[index];
          final isSelected = _selectedItem?.id == item.id;
          
          return Card(
            key: ValueKey('card_${item.id}'),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              side: isSelected 
                  ? BorderSide(color: Colors.blue.shade700, width: 2)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: () {
                // Handle selection state
                setState(() {
                  if (_selectedItem?.id == item.id) {
                    _selectedItem = null; // Deselect if already selected
                  } else {
                    _selectedItem = item; // Select the item
                  }
                });
                
                // Add to cart (still maintain this functionality)
                orderProvider.addToCart(item);
                
                // Show an informational message if item is out of stock
                if (!item.isAvailable) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${item.name}" is out of stock but has been added to your order'.tr()),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          child: _buildItemImage(item),
                        ),  
                        if (!item.isAvailable)
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            child:  Center(
                              child: Text(
                                'Out of stock'.tr(),
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.price.toStringAsFixed(3),
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 10,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.isAvailable ? 'Available'.tr() : 'Out of stock'.tr(),
                              style: TextStyle(
                                color: item.isAvailable ? Colors.green : Colors.red,
                                fontSize: 10,
                              ),
                            ),
                            if (item.kitchenNote.isNotEmpty)
                              Icon(
                                Icons.note_alt_outlined,
                                size: 12,
                                color: Colors.blue.shade700,
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
        },
      ),
    ),
  );
}

  Widget _buildItemImage(MenuItem item) {
    // Handle empty image URL
    if (item.imageUrl.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        child: const Center(child: Icon(Icons.image_not_supported)),
      );
    }

    // Create a unique key for each image to maintain state
    final imageKey = ValueKey('${item.id}_image');

    // Handle base64 images
    if (item.imageUrl.startsWith('data:image')) {
      try {
        if (!_imageCache.containsKey(item.id)) {

        // Parse base64 data
        final parts = item.imageUrl.split(',');
        if (parts.length != 2) {
          return Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image));
        }
        
        
        String base64String = parts[1];
        
        // Clean and prepare base64 data - only do this once
        base64String = base64String.replaceAll(RegExp(r'\s+'), '');
        // base64String = base64String.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
        
        // Fix padding
        int padding = (4 - (base64String.length % 4)) % 4;
        base64String = base64String.padRight(base64String.length + padding, '=');
        // Decode and store in cache
        _imageCache[item.id] = base64Decode(base64String);
      }
         // Use cached decoded data
      return Image.memory(
        _imageCache[item.id]!,
        fit: BoxFit.cover,
        key: imageKey,
        gaplessPlayback: true,
        cacheWidth: 300,
        cacheHeight: 300,
      );
      } catch (e) {
        return Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image));
      }
    }
    
    // Handle network images with better caching
    return CachedNetworkImage(
      imageUrl: item.imageUrl,
      fit: BoxFit.cover,
      key: imageKey,
      memCacheWidth: 300, // Set appropriate cache sizes
      memCacheHeight: 300,
      fadeInDuration: const Duration(milliseconds: 0), // Remove fade animation
      fadeOutDuration: const Duration(milliseconds: 0),
      placeholder: (context, url) => Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        return Container(
          color: Colors.grey.shade300,
          child: const Center(child: Icon(Icons.broken_image)),
        );
      },
    );
  }

  // Replace the existing _buildOrderPanel method
// This is a partial code update - only replace the order panel section

Widget _buildOrderPanel(OrderProvider orderProvider) {
  return Container(
    width: 350,
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child:  Text(
            'Order Items'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Order items list or empty cart message - this is scrollable
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                orderProvider.cartItems.isEmpty
                    ? _buildEmptyCartMessage()
                    : ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: orderProvider.cartItems.length,
                        itemBuilder: (ctx, index) {
                          final item = orderProvider.cartItems[index];
                          return Container(
                            key: ValueKey('cart_item_${item.id}'),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Item name and price - more space for name
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (!item.isAvailable)
                                            Container(
                                              margin: const EdgeInsets.only(left: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Out of stock'.tr(),
                                                style: TextStyle(
                                                  color: Colors.red.shade900,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.price.toStringAsFixed(3)} × ${item.quantity}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Quantity adjustment and controls with reduced spacing
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 14),
                                      onPressed: () {
                                        if (item.quantity > 1) {
                                          orderProvider.updateItemQuantity(item.id, item.quantity - 1);
                                        } else {
                                          orderProvider.removeItem(item.id);
                                        }
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      style: IconButton.styleFrom(
                                        minimumSize: const Size(20, 20),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 24,
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 14),
                                      onPressed: () {
                                        orderProvider.updateItemQuantity(item.id, item.quantity + 1);
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      style: IconButton.styleFrom(
                                        minimumSize: const Size(20, 20),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        (item.price * item.quantity).toStringAsFixed(3),
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                        textAlign: TextAlign.right,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.grey, size: 14),
                                      onPressed: () {
                                        orderProvider.removeItem(item.id);
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      style: IconButton.styleFrom(
                                        minimumSize: const Size(20, 20),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                
                // Create a visual separator between order items and billing section
                Container(
                  height: 10,
                  color: Colors.grey.shade50,
                ),
                
                // Order summary section
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Subtotal row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text('Sub total'.tr(), style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(orderProvider.subtotal.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Additional charges rows
                      _buildSummaryRow('Tax amount'.tr(), '0.000'),
                      // _buildSummaryRow('Item discount'.tr(), '0.000'),
                      // _buildSummaryRow('Bill discount'.tr(), '0.000'),
                      // _buildSummaryRow('Delivery charge'.tr(), '0.000'),
                      // _buildSummaryRow('Surcharge'.tr(), '0.000'),
                      
                      const SizedBox(height: 8),
                      // Grand total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text('Grand total'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(orderProvider.total.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Date visited, Count visited, Point
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Text('Date visited'.tr(), style: TextStyle(fontSize: 11)),
                                const SizedBox(height: 6),
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                      "${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}",
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Text('Count visited'.tr(), style: TextStyle(fontSize: 11)),
                                const SizedBox(height: 6),
                                Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Text('Point'.tr(), style: TextStyle(fontSize: 11)),
                                const SizedBox(height: 6),
                                Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.person_outline, color: widget.serviceColor),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const PersonFormScreen()
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.search, color: widget.serviceColor ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const SearchPersonScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // FIXED PAYMENT BUTTONS SECTION - always at the bottom
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First row of buttons
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentButton('Cash'.tr(), Colors.grey.shade100),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentButton('Credit'.tr(), Colors.grey.shade100),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Second row of buttons
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentButton('Order'.tr(), Colors.grey.shade100),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentButton('Tender'.tr(), Colors.grey.shade100),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  

  // New method to display empty cart message
  Widget _buildEmptyCartMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          // Text(
          //   'Select menu items to add them to your order',
          //   textAlign: TextAlign.center,
          //   style: TextStyle(
          //     fontSize: 14,
          //     color: Colors.grey.shade600,
          //   ),
          // ),
          const SizedBox(height: 30),
          // Add a divider to separate from billing section
          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }
  Widget _buildPaymentButton(String text, Color color) {
  return SizedBox(
    width: 130,
    height: 50,
    child: OutlinedButton(
      onPressed: () async {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        
        if (orderProvider.cartItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please add items to your order'.tr())),
          );
          return;
        }
        
        // For Credit button - just navigate to SearchPersonScreen
        if (text == "Credit".tr()) {
          final selectedPerson = await Navigator.push<Person>(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchPersonScreen(),
            ),
          );
          
          if (selectedPerson != null) {
            orderProvider.setSelectedPerson(selectedPerson);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Customer selected: ${selectedPerson.name}')),
              );
            }
          }
          return;
        }

        try {
          // For Cash or Tender button - navigate to TenderScreen first, then create/update order
          if (text == "Cash".tr() || text == "Tender".tr()) {
            // Convert cart items to order items
            final orderItems = orderProvider.cartItems.map((menuItem) => 
              OrderItem(
                id: int.parse(menuItem.id),
                name: menuItem.name,
                price: menuItem.price,
                quantity: menuItem.quantity,
                kitchenNote: menuItem.kitchenNote,
              )
            ).toList();

            // Use existing order ID if we're editing an order
            final orderId = widget.existingOrderId;
            
            // Create a temporary Order object for TenderScreen
            final tempOrder = Order(
              id: orderId, // Pass existing ID if editing an order
              serviceType: widget.serviceType,
              items: orderItems,
              subtotal: orderProvider.subtotal,
              tax: orderProvider.tax,
              discount: 0.0,
              total: orderProvider.total,
              status: 'pending',
              customerId: orderProvider.selectedPerson?.id
            );
            
            // Convert to OrderHistory for TenderScreen
            final orderHistory = OrderHistory.fromOrder(tempOrder);

            // Navigate to TenderScreen with the temporary order
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TenderScreen(
                  order: orderHistory,
                  isEdited: orderId != null, // Set isEdited based on whether we have an existing order ID
                  taxRate: Provider.of<SettingsProvider>(context, listen: false).taxRate,
                  preselectedPaymentMethod: text == "Cash".tr() ? 'Cash' : 'Bank',
                  showBankDialogOnLoad: text == "Tender".tr(),
                  customer: orderProvider.selectedPerson,
                ),
              ),
            );
            
            // If we got a result back, it means the order was successfully processed
            if (result == true) {
              // Clear the cart after successful payment
              orderProvider.clearCart();
              orderProvider.clearSelectedPerson();
            }
          }
          else if (text == "Order".tr()) {
            // Existing order flow - send to OrderConfirmationScreen
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => OrderConfirmationScreen(
                  serviceType: widget.serviceType,
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${e.toString()}')),
            );
          }
          debugPrint('Error processing payment: $e');
        }
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: color,
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black)),
    ),
  );
}
 
}
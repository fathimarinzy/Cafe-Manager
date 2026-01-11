import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  int _menuRows = 4;
  int _menuColumns = 5;

  // Helper method to check if there are any tax-exempt items in the cart
  bool _hasTaxExemptItems(OrderProvider orderProvider) {
    return orderProvider.cartItems.any((item) => item.taxExempt);
  }

  final List<Map<String, dynamic>> _menuLayoutOptions = [
      {'label': '3x3 Layout', 'rows': 3, 'columns': 3},
      {'label': '4x4 Layout', 'rows': 4, 'columns': 4},
      {'label': '4x5 Layout', 'rows': 4, 'columns': 5},
      {'label': '4x6 Layout', 'rows': 4, 'columns': 6},
      {'label': '5x7 Layout', 'rows': 5, 'columns': 7},
      {'label': '5x8 Layout', 'rows': 5, 'columns': 8},
      // {'label': '6x6 Layout', 'rows': 6, 'columns': 6},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMenu();
    _updateTime();
    _loadKotPrinterSettings(); // Add this line
    _loadMenuLayoutSettings(); // Load saved menu layout settings

    
   // Set the current service type and order ID in OrderProvider
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
     orderProvider.setCurrentServiceType(widget.serviceType);
     // Only clear selected person if NOT delivery OR catering
     final serviceLower = widget.serviceType.toLowerCase();
     if (!serviceLower.contains('delivery') && !serviceLower.contains('catering')) {
       orderProvider.clearSelectedPerson();
     }
    
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
Future<void> _loadMenuLayoutSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _menuRows = prefs.getInt('menu_item_rows') ?? 4;
      _menuColumns = prefs.getInt('menu_item_columns') ?? 5;
    });
  } catch (e) {
    debugPrint('Error loading menu layout settings: $e');
  }
}

void _showMenuLayoutDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      final screenWidth = MediaQuery.of(context).size.width;
      
      return AlertDialog(
        title: Text(
          'Select Menu Layout'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        content: SizedBox(
          width: screenWidth * 0.65,
          child: ListView(
            shrinkWrap: true,
            children: _menuLayoutOptions.map((option) {
              return ListTile(
                dense: true,
                title: Text(
                  option['label'],
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _menuRows = option['rows'];
                    _menuColumns = option['columns'];
                  });
                  _saveMenuLayout(option['rows'], option['columns']);
                  Navigator.pop(context);
                },
                trailing: (_menuRows == option['rows'] && _menuColumns == option['columns']) 
                  ? const Icon(Icons.check, color: Colors.green, size: 18)
                  : null,
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel'.tr(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _saveMenuLayout(int rows, int columns) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('menu_item_rows', rows);
    await prefs.setInt('menu_item_columns', columns);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Menu layout saved'.tr())),
      );
    }
  } catch (e) {
    debugPrint('Error saving menu layout settings: $e');
  }
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
    // Invalidate cache if menu items have changed (length check is a simple way to detect changes)
    final currentItemsLength = menuProvider.items.length;
    
    // Only recalculate if category, search, or items have changed
    if (_cachedItems != null && 
        _lastCategory == _selectedCategory && 
        _lastSearchQuery == _itemSearchQuery &&
        _cachedItems!.length == currentItemsLength) {
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
    
    
    // Filter out "Per Plate" items UNLESS we are in Catering mode
    if (!widget.serviceType.toLowerCase().contains('catering')) {
      items = items.where((item) => !item.isPerPlate).toList();
    }

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
      final isMobile = MediaQuery.of(context).size.width < 600;
      bool shouldUpdate = false;
      
      // Calculate desired category
      String targetCategory = _selectedCategory;
      if (!isMobile && (_selectedCategory.isEmpty || 
          !menuProvider.categories.contains(_selectedCategory))) {
        targetCategory = menuProvider.categories.isNotEmpty ? 
            menuProvider.categories.first : '';
        if (targetCategory != _selectedCategory) {
          shouldUpdate = true;
        }
      }

      // Only setState if we need to change category OR if we were loading
      if (shouldUpdate || _isLoading) {
        setState(() {
          if (shouldUpdate) {
            _selectedCategory = targetCategory;
          }
          _isLoading = false;
        });
      }
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
    final orientation = MediaQuery.of(context).orientation;
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait = orientation == Orientation.portrait;
    final isMobile = screenWidth < 600;
    
    // Watch settings changes without creating an unused variable
    context.watch<SettingsProvider>();

    // When the tax rate changes in settings, update the orderProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      orderProvider.setContext(context);
      
      // Recalculate totals when tax rate changes
      final currentCart = orderProvider.cartItems;
      if (currentCart.isNotEmpty) {
        // Force a recalculation of totals by triggering a change
        for (var item in currentCart) {
          orderProvider.updateItemQuantity(item.id, item.quantity);
          break; // Just need to update one item to trigger recalculation
        }
      }
    });

    // Use the cached/memoized items list
    List<MenuItem> displayedItems = _getDisplayedItems(menuProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          await _loadMenu();
          return;
        }
        // Handle Android Back Button to navigate up category hierarchy
        if (isMobile && _selectedCategory.isNotEmpty) {
           setState(() {
             _selectedCategory = '';
             _itemSearchQuery = '';
             _cachedItems = null;
           });
        } else {
           Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: isMobile // Simplified AppBar for mobile
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                   if (_selectedCategory.isNotEmpty) {
                     setState(() {
                       _selectedCategory = '';
                       _itemSearchQuery = '';
                       _cachedItems = null;
                     });
                   } else {
                     Navigator.of(context).pop();
                   }
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.serviceType, style: const TextStyle(color: Colors.black, fontSize: 16)),
                  Text(_currentTime, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
              actions: [
                IconButton(icon: Icon(Icons.print, color: _isKotPrinterEnabled ? Colors.blue : Colors.grey), onPressed: _toggleKotPrinterConnection),
              ],
            )
          : AppBar(
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
            // Kitchen Printer Toggle Button (Moved First)
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

            // Menu Layout Button (Moved Right)
            IconButton(
              onPressed: _showMenuLayoutDialog,
              icon: Icon(
                Icons.grid_view,
                color: Colors.blue.shade700,
                size: 24,
              ),
              tooltip: 'Menu Layout'.tr(),
            ),
            const SizedBox(width: 8),
            // Order List button
            TextButton.icon(  
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderListScreen(serviceType: widget.serviceType, fromMenuScreen: true),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long, color: Colors.black, size: 20),
              label: Text('Order List'.tr(), style: TextStyle(color: Colors.black, fontSize: 14)),
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
        body: isMobile 
            ? _buildPhoneLayout(menuProvider, orderProvider, displayedItems)
            : (isPortrait
                ? _buildPortraitLayout(menuProvider, orderProvider, displayedItems)
                : _buildLandscapeLayout(menuProvider, orderProvider, displayedItems)),
                    
                    
                    
        bottomNavigationBar: _buildBottomNavigationBar(isPortrait),
      ),
    );
  }

  // Mobile Phone Layout (Width < 600)
  Widget _buildPhoneLayout(MenuProvider menuProvider, OrderProvider orderProvider, List<MenuItem> displayedItems) {
    // If no category selected (and no search active), show full screen category grid
    if (_selectedCategory.isEmpty && _itemSearchQuery.isEmpty) {
      return Column(
        children: [
           // Search Bar for Categories/Items
           Padding(
             padding: const EdgeInsets.all(16.0),
             child: TextField(
               decoration: InputDecoration(
                 hintText: "Search menu...".tr(),
                 prefixIcon: const Icon(Icons.search),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                 filled: true,
                 fillColor: Colors.grey.shade100,
                 contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               ),
               onChanged: (val) {
                 setState(() {
                   _itemSearchQuery = val;
                   _cachedItems = null;
                 });
               },
             ),
           ),
           Expanded(child: _buildCategoryGrid(menuProvider.categories)),
           _buildMobileBottomBar(orderProvider),
        ],
      );
    }

    // Otherwise show the Product List (Sub-categories)
    return Column(
      children: [
        // Top: Selected Category + Back Button (simulated header)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedCategory = '';
                    _itemSearchQuery = '';
                    _cachedItems = null;
                  });
                },
              ),
              Expanded(
                child: Text(
                  _selectedCategory, 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Optional: Horizontal list could be here, but let's stick to "Focus on Items"
            ],
          ),
        ),
        Container(height: 1, color: Colors.grey.shade300),
        
        // Body: Product Grid
        Expanded(
          child: Column(
            children: [
               // Search within category
               if (_selectedCategory.isNotEmpty)
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                   child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search in $_selectedCategory...".tr(),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onChanged: (val) {
                       setState(() {
                         _itemSearchQuery = val; 
                         _cachedItems = null;
                       });
                    },
                   ),
                 ),

               Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildProductGrid(displayedItems, orderProvider, crossAxisCount: _menuColumns),
               ),
            ],
          ),
        ),
        
        // Bottom: Condensed Order Bar (Always visible)
        _buildMobileBottomBar(orderProvider),
      ],
    );
  }

  Widget _buildCategoryGrid(List<String> categories) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // Even denser (from 4)
        childAspectRatio: 0.85, // Taller to fit text in narrow space
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        // Warm/Appetizing color scheme
        final color = Colors.orange.shade50;
        final textColor = Colors.brown.shade800;
        final borderColor = Colors.orange.shade100;

        return Material(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor),
          ),
          elevation: 0,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedCategory = category;
                _cachedItems = null;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  category,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11, // Smaller text
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  // Widget _buildHorizontalCategories(List<String> categories) {
  //   return ListView.builder(
  //     scrollDirection: Axis.horizontal,
  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //     itemCount: categories.length,
  //     itemBuilder: (context, index) {
  //       final category = categories[index];
  //       final isSelected = _selectedCategory == category;
  //       return Padding(
  //         padding: const EdgeInsets.only(right: 8),
  //         child: InkWell(
  //           onTap: () {
  //             setState(() {
  //               _selectedCategory = category;
  //               _cachedItems = null;
  //             });
  //           },
  //           borderRadius: BorderRadius.circular(20),
  //           child: AnimatedContainer(
  //             duration: const Duration(milliseconds: 200),
  //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //             decoration: BoxDecoration(
  //               color: isSelected ? widget.serviceColor : Colors.grey.shade100,
  //               borderRadius: BorderRadius.circular(20),
  //               border: Border.all(
  //                 color: isSelected ? widget.serviceColor : Colors.transparent,
  //                 width: 1,
  //               ),
  //               boxShadow: isSelected 
  //                   ? [BoxShadow(color: widget.serviceColor.withAlpha(77), blurRadius: 4, offset: Offset(0, 2))]
  //                   : [],
  //             ),
  //             child: Center(
  //               child: Text(
  //                 category,
  //                 style: TextStyle(
  //                   color: isSelected ? Colors.white : Colors.grey.shade800,
  //                   fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
  //                   fontSize: 14,
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildMobileBottomBar(OrderProvider orderProvider) {
    final total = orderProvider.total;
    final itemCount = orderProvider.cartItems.fold<int>(0, (sum, item) => sum + item.quantity);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("$itemCount Items".tr(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(
                    "\$${total.toStringAsFixed(2)}", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.serviceColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => _showMobileOrderSheet(context, orderProvider),
              icon: Icon(Icons.shopping_cart_checkout),
              label: Text("View Order".tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileOrderSheet(BuildContext context, OrderProvider orderProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
             // Handle bar
             Center(child: Container(margin: EdgeInsets.only(top: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
             // Header
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text("Current Order".tr(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                 ],
               ),
             ),
             Divider(height: 1),
             // Reuse existing order panel content logic, but wrapped differently
             Expanded(child: _buildOrderPanel(orderProvider, isPortrait: true, isMobileSheet: true)),
          ],
        ),
      ),
    );
  }

  // Portrait layout - Stack categories and products vertically, order panel at bottom
  Widget _buildPortraitLayout(MenuProvider menuProvider, OrderProvider orderProvider, List<MenuItem> displayedItems) {
    return Column(
      children: [
        // Top section: Categories sidebar (horizontal scroll) and product grid
        Expanded(
          flex: 7, // Take up 70% of the screen
          child: Row(
            children: [
              // Categories sidebar - narrower in portrait
              Container(
                width: 200, // Reduced width for portrait
                color: Colors.grey.shade50,
                child: _buildCategorySidebarContent(menuProvider.categories),
              ),
              Container(
                width: 1.0,
                color: Colors.grey.shade300,
              ),
              // Product grid - takes remaining space
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryHeader(),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildProductGrid(displayedItems, orderProvider, crossAxisCount: _menuColumns), // Fewer columns in portrait
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 1.0,
          color: Colors.grey.shade300,
        ),
        // Bottom section: Order panel - horizontal layout
        SizedBox(
          height: 350, // Reduced height for Horizontal Layout (More efficient)
          child: _buildPortraitOrderPanel(orderProvider),
        ),
      ],
    );
  }

  // Landscape layout 
  Widget _buildLandscapeLayout(MenuProvider menuProvider, OrderProvider orderProvider, List<MenuItem> displayedItems) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Categories sidebar
        Container(
          width: 250,
          color: Colors.grey.shade50,
          child: _buildCategorySidebarContent(menuProvider.categories),
        ),
        Container(
          width: 1.0,
          color: Colors.grey.shade300,
        ),
        // Product grid
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildProductGrid(displayedItems, orderProvider, crossAxisCount: _menuColumns), // More columns in landscape
              ),
            ],
          ),
        ),
        Container(
          width: 1.0,
          color: Colors.grey.shade300,
        ),
        // Order panel
        _buildOrderPanel(orderProvider, isPortrait: false),
      ],
    );
  }

  // Updated category sidebar content (extracted for reuse)
  Widget _buildCategorySidebarContent(List<String> categories) {
    final filteredCategories = categories;
    final lightBgColor = getLightBackgroundColor(widget.serviceColor);

    return Column(
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
                _itemSearchQuery = value;
                _cachedItems = null;
                if (value.isNotEmpty) {
                  _selectedCategory = '';
                } else if (filteredCategories.isNotEmpty) {
                  _selectedCategory = filteredCategories.first;
                }
              });
            },
          ),
        ),
        Container(
          height: 1.0,
          color: Colors.grey.shade300,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: []),
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
                      _cachedItems = null;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
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

  Widget _buildProductGrid(List<MenuItem> items, OrderProvider orderProvider, {required int crossAxisCount}) {
  // Use the passed crossAxisCount directly (which will now be _menuColumns)
  // final int responsiveColumns = crossAxisCount;
  return Container(
    color: Colors.grey.shade100,
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: items.isEmpty 
          ? Center(child: Text('No items found in this category'.tr()))
          : LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive column count based on available width
                final availableWidth = constraints.maxWidth;
                const double spacing = 8.0;

                // Determine columns: attempt to fit cards of ~160-200 width
                // For Mobile (< 600) -> 2 or 3
                // For Tablet (600 - 1200) -> 4 or 5
                // For Desktop (> 1200) -> Use setting or calculated max
                
                int responsiveColumns = crossAxisCount; // Default to specific setting (Tablet/Desktop behavior)
                
                
                final screenWidth = MediaQuery.of(context).size.width;

                if (screenWidth < 600) {
                  // Mobile (Phone)
                  responsiveColumns = 2;
                } // else if (screenWidth >= 600 && screenWidth < 1000) {
                   // Tablet Portrait: Use user's saved preference
                   // responsiveColumns = 4;
                // } else if (screenWidth >= 1000) {
                   // Tablet Landscape / Desktop: Use user's saved preference
                   // responsiveColumns = 4;
                  
                  // Optional: Extra check for very small devices? 
                  // if (availableWidth < 300) responsiveColumns = 1;
 
                // For Tablet/Desktop (>= 600), we simply respect the 'responsiveColumns' 
                // which is initialized to 'crossAxisCount' (the user's layout preference).
                // We DO NOT override it, ensuring Tablet UI remains exactly as configured.

                // Recalculate dimensions based on FINAL responsiveColumns
                final itemWidth = (availableWidth - (spacing * (responsiveColumns + 1))) / responsiveColumns;
                final imageHeight = itemWidth * 0.55; // Slightly reduced image height
                // Add fixed height for content to avoid overflow issues on small screens
                final contentHeight = 81.0; // Increased by 1 to eliminate sub-pixel overflow
                final totalItemHeight = imageHeight + contentHeight;
                final aspectRatio = itemWidth / totalItemHeight;
                
                return GridView.builder(
                  padding: EdgeInsets.zero,
                  // Optimizations for low-end devices
                  addAutomaticKeepAlives: false,
                  cacheExtent: 100,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: responsiveColumns,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, index) {
                    final item = items[index];
                    final isSelected = _selectedItem?.id == item.id;
                    
                    return Card(
                      key: ValueKey('card_${item.id}'),
                      elevation: 0, // Removed shadow for performance
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                        side: isSelected 
                            ? BorderSide(color: Colors.blue.shade700, width: 1.5)
                            : BorderSide(color: Colors.grey.shade200), // Simple border instead of shadow
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (_selectedItem?.id == item.id) {
                              _selectedItem = null;
                            } else {
                              _selectedItem = item;
                            }
                          });
                          
                          orderProvider.addToCart(item);
                          
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
                            // Image section - responsive height
                            SizedBox(
                              height: imageHeight,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                    child: _buildItemImage(item),
                                  ),  
                                  if (!item.isAvailable)
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Out of stock'.tr(),
                                          style: TextStyle(
                                            color: Colors.white, 
                                            fontSize: (itemWidth * 0.08).clamp(10.0, 16.0),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Content section - responsive height with equal padding
                            Expanded(
                              child: ClipRect(
                                child: Padding(
                                  padding: EdgeInsets.all((itemWidth * 0.04).clamp(6.0, 12.0)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Item name
                                        Text(
                                          item.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: (itemWidth * 0.09).clamp(12.0, 18.0),
                                            height: 1.2,
                                            decoration: TextDecoration.none,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        // Price and status section
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              item.price.toStringAsFixed(3),
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: (itemWidth * 0.06).clamp(10.0, 13.0),
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            // Status and note
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.isAvailable ? 'Available'.tr() : 'Out of stock'.tr(),
                                                    style: TextStyle(
                                                      color: item.isAvailable ? Colors.green : Colors.red,
                                                      fontSize: (itemWidth * 0.06).clamp(9.0, 12.0),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (item.kitchenNote.isNotEmpty)
                                                  Icon(
                                                    Icons.note_alt_outlined,
                                                    size: (itemWidth * 0.08).clamp(12.0, 18.0),
                                                    color: Colors.blue.shade700,
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
      child: const Center(child: Icon(Icons.image_not_supported, size: 20)), // Smaller icon
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
          return Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image, size: 20));
        }
        
        String base64String = parts[1];
        base64String = base64String.replaceAll(RegExp(r'\s+'), '');
        
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
        cacheWidth: 100, // Aggressively reduced for low-end devices
        cacheHeight: 100,
      );
    } catch (e) {
      return Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image, size: 20));
    }
  }
  
  // Handle network images with better caching
  return CachedNetworkImage(
    imageUrl: item.imageUrl,
    fit: BoxFit.cover,
    key: imageKey,
    memCacheWidth: 100, // Aggressively reduced for low-end devices
    memCacheHeight: 100,
    fadeInDuration: const Duration(milliseconds: 0),
    fadeOutDuration: const Duration(milliseconds: 0),
    placeholder: (context, url) => Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: SizedBox(
          width: 20, // Smaller loading indicator
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
    errorWidget: (context, url, error) {
      return Container(
        color: Colors.grey.shade300,
        child: const Center(child: Icon(Icons.broken_image, size: 20)), // Smaller icon
      );
    },
  );
}

  // Updated order panel that adapts to portrait/landscape


  // Portrait order panel - horizontal layout with scrollable items
  Widget _buildPortraitOrderPanel(OrderProvider orderProvider) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Container(
      color: Colors.white,
      child: Row(
        children: [
          // Order items section - takes most of the space
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Text(
                    'Order Items'.tr(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: orderProvider.cartItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.grey.shade400),
                              SizedBox(height: 8),
                              Text('Cart is empty'.tr(), style: TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: orderProvider.cartItems.length,
                          itemBuilder: (ctx, index) {
                            final item = orderProvider.cartItems[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                              ),
                              child: Row(
                                children: [
                                  // Item name and price
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                                        Text('${item.price.toStringAsFixed(3)} × ${item.quantity}', 
                                             style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  // Quantity controls
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 12),
                                        onPressed: () {
                                          if (item.quantity > 1) {
                                            orderProvider.updateItemQuantity(item.id, item.quantity - 1);
                                          } else {
                                            orderProvider.removeItem(item.id);
                                          }
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        style: IconButton.styleFrom(minimumSize: const Size(20, 20)),
                                      ),
                                      SizedBox(width: 20, child: Text('${item.quantity}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 12),
                                        onPressed: () => orderProvider.updateItemQuantity(item.id, item.quantity + 1),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        style: IconButton.styleFrom(minimumSize: const Size(20, 20)),
                                      ),
                                    ],
                                  ),
                                  // Total and remove
                                  SizedBox(
                                    width: 40,
                                    child: Text((item.price * item.quantity).toStringAsFixed(3), 
                                               style: const TextStyle(fontSize: 11), textAlign: TextAlign.right),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 12),
                                    onPressed: () => orderProvider.removeItem(item.id),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    style: IconButton.styleFrom(minimumSize: const Size(20, 20)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          Container(width: 1.0, color: Colors.grey.shade300),
          // Summary and payment buttons section
          SizedBox(
            width: 280,
            child: Column(
              children: [
                // Order summary
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildSummaryRow('Sub total'.tr(), orderProvider.subtotal.toStringAsFixed(3)),
                        // Tax row with VAT type indicator
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text('Tax amount'.tr()),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      settingsProvider.isVatInclusive ? 'Incl.' : 'Excl.',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                                   // Show tax-exempt indicator if there are tax-exempt items
                                  if (_hasTaxExemptItems(orderProvider))
                                    Container(
                                      margin: const EdgeInsets.only(left: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Tooltip(
                                        message: 'Some items are tax-exempt'.tr(),
                                        child: Icon(
                                          Icons.info_outline,
                                          size: 10,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text(orderProvider.tax.toStringAsFixed(3)),
                            ],
                          ),
                        ),
                        // Delivery Charge Row (Portrait)
                        if ((orderProvider.deliveryCharge ?? 0) > 0 && widget.serviceType.toLowerCase().contains('delivery'))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Delivery Fee'.tr()),
                                Text((orderProvider.deliveryCharge ?? 0).toStringAsFixed(3)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Grand total'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(orderProvider.total.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Customer selection icons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(Icons.person_outline, color: widget.serviceColor),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PersonFormScreen()),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.search, color: widget.serviceColor),
                              onPressed: () async {
                                final selectedPerson = await Navigator.push<Person>(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SearchPersonScreen()),
                                );
                                if (selectedPerson != null) {
                                  orderProvider.setSelectedPerson(selectedPerson);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Customer selected: ${selectedPerson.name}'),
                                      duration: const Duration(milliseconds: 100)),
                                    );
                                  }
                                }
                              },
                            ),
                            Builder(
                              builder: (context) {
                                final isDelivery = widget.serviceType.toLowerCase().contains('delivery');
                                debugPrint('DEBUG_PORTRAIT: ServiceType: ${widget.serviceType}, isDelivery: $isDelivery');
                                if (isDelivery) {
                                  return IconButton(
                                    icon: Icon(Icons.local_shipping, color: widget.serviceColor),
                                    onPressed: _showDeliveryDetailsDialog,
                                  );
                                }
                                return const SizedBox.shrink();
                              }
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Payment buttons - horizontal layout
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
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

                const SizedBox(height: 8),
                // Second row of buttons
                Row(
                  children: [
                    if (widget.serviceType.toLowerCase().contains('catering')) ...[
                      Expanded(
                        child: _buildPaymentButton('Quote'.tr(), Colors.orange.shade50, textColor: Colors.orange.shade800, onTap: () => _showQuoteConfirmation()),
                      ),
                      const SizedBox(width: 8),
                    ],
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
          ),
        ],
      ),
    );
  }

  // Order Panel Widget
  Widget _buildOrderPanel(OrderProvider orderProvider, {bool isPortrait = true, bool isMobileSheet = false}) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    // If it's a mobile sheet, we want to expand to fill the available space (modal)
    // If it's portrait/landscape desktop, we use fixed sizes usually
    
    return Container(
      width: isMobileSheet ? double.infinity : 350, // Full width for mobile sheet, fixed for desktop
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobileSheet) ...[ // Hide header if in mobile sheet (custom header provided)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Items'.tr(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (widget.serviceType.toLowerCase().contains('delivery'))
                    IconButton(
                      icon: const Icon(Icons.local_shipping, color: Colors.blue), // Hardcoded color for visibility check
                      tooltip: 'Delivery Details',
                      onPressed: _showDeliveryDetailsDialog,
                    ),
                ],
              ),
            ),
          ],
          
          // Order items list
          Expanded(
            child: orderProvider.cartItems.isEmpty
                ? _buildEmptyCartMessage()
                : ListView.builder(
                    padding: EdgeInsets.only(bottom: isMobileSheet ? 100 : 0), // Padding for floating buttons if any
                    physics: const NeverScrollableScrollPhysics(), // Keep this for nested ListView
                    shrinkWrap: true, // Keep this for nested ListView
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
                                  // Item name and price
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
                                                  'Sold Out'.tr(),
                                                  style: TextStyle(
                                                    color: Colors.red.shade900,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            else if (item.isPerPlate)
                                              Container(
                                                margin: const EdgeInsets.only(left: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Per Person'.tr(),
                                                  style: TextStyle(
                                                    color: Colors.purple.shade900,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.price.toStringAsFixed(3)} x ${item.quantity}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Quantity adjustment
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
                  ),
                  
                  // Separator
                  Container(
                    height: 10,
                    color: Colors.grey.shade50,
                  ),
                  
                  // Order Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Sub total'.tr(), style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(orderProvider.subtotal.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text('Tax amount'.tr()),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    settingsProvider.isVatInclusive ? 'Incl.' : 'Excl.',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ),
                                if (_hasTaxExemptItems(orderProvider))
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Tooltip(
                                      message: 'Some items are tax-exempt'.tr(),
                                      child: Icon(
                                        Icons.info_outline,
                                        size: 12,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(orderProvider.tax.toStringAsFixed(3)),
                          ],
                        ),
                        
                        if ((orderProvider.deliveryCharge ?? 0) > 0 && widget.serviceType.toLowerCase().contains('delivery'))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Delivery Fee'.tr()),
                                Text((orderProvider.deliveryCharge ?? 0).toStringAsFixed(3)),
                              ],
                            ),
                          ),
                          
                        const SizedBox(height: 8),
                        
                        // Grand Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Grand total'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(orderProvider.total.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Customer selection row 
                        Container(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(Icons.person_outline, color: widget.serviceColor),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const PersonFormScreen())
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.search, color: widget.serviceColor),
                                onPressed: () async {
                                  final selectedPerson = await Navigator.push<Person>(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SearchPersonScreen())
                                  );
                                  if (selectedPerson != null) {
                                    orderProvider.setSelectedPerson(selectedPerson);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Customer selected: ${selectedPerson.name}'), duration: const Duration(milliseconds: 100)),
                                      );
                                    }
                                  }
                                },
                              ),
                              Builder(
                                builder: (context) {
                                  final isDelivery = widget.serviceType.toLowerCase().contains('delivery');
                                  // debugPrint('DEBUG: ServiceType: ${widget.serviceType}, isDelivery: $isDelivery');
                                  if (isDelivery) {
                                    return IconButton(
                                      icon: Icon(Icons.local_shipping, color: widget.serviceColor),
                                      onPressed: _showDeliveryDetailsDialog,
                                    );
                                  }
                                  return const SizedBox.shrink(); // Hidden if not delivery
                                }
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
          
          // Payment Buttons
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
                Row(
                  children: [
                    Expanded(child: _buildPaymentButton('Cash'.tr(), Colors.grey.shade100)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildPaymentButton('Credit'.tr(), Colors.grey.shade100)),
                  ],
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.serviceType.toLowerCase().contains('catering')) ...[
                      Expanded(
                        child: _buildPaymentButton('Quote'.tr(), Colors.orange.shade50, textColor: Colors.orange.shade800, onTap: () => _showQuoteConfirmation()),
                      ),
                      const SizedBox(width: 8),
                    ],
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

  // Updated bottom navigation bar that adapts to orientation
  Widget _buildBottomNavigationBar(bool isPortrait) {
    if (isPortrait) {
      // In portrait, show fewer buttons or make them scrollable
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: SafeArea(
          child: Container(
            height: 60, // Increased height for better touch targets
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min, // Important: prevents unbounded width
                children: [
                  _buildNavButtonScrollable(Icons.arrow_back_ios, null, ''),
                  _buildNavButtonScrollable(null, null, 'Kitchen note'.tr()),
                  _buildNavButtonScrollable(null, null, 'Clear'.tr()),
                  _buildNavButtonScrollable(null, null, 'Order List'.tr()),
                  _buildNavButtonScrollable(Icons.arrow_forward_ios, null, ''),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // In landscape, show all buttons as before
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: SafeArea(
          child: Container(
             height: 60, // Increased height
             padding: const EdgeInsets.symmetric(vertical: 4),
             child: Row(
              children: [
                _buildNavButton(Icons.arrow_back_ios, null, ''),
                _buildNavButton(null, null, 'Kitchen note'.tr()),
                _buildNavButton(null, null, 'Clear'.tr()),
                _buildNavButton(null, null, 'Order List'.tr()),
                _buildNavButton(Icons.arrow_forward_ios, null, ''),
              ],
            ),
          ),
        ),
      );
    }
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
                  builder: (context) => ModifierScreen(
                    allowPerPlatePricing: widget.serviceType.toLowerCase().contains('catering'),
                  )
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
                    title: Text('Clear Order'.tr(),style: TextStyle(
                      fontSize: 18, // Smaller font size (default is usually 20-22)
                      fontWeight: FontWeight.bold,
                    ),
                    ),
                    content: Text('Are you sure you want to clear all items from this order?'.tr()),
                    actions: [
                      TextButton(
                        child: Text('Cancel'.tr()),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      TextButton(
                        child: Text('Clear'.tr(), style: TextStyle(color: Colors.red)),
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
                  builder: (context) => const TableManagementScreen(),
                  settings: const RouteSettings(name: 'TableManagementScreen'),
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
                  settings: const RouteSettings(name: 'OrderListScreen'),
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

  // Navigation button for scrollable horizontal layout (portrait mode)
  Widget _buildNavButtonScrollable(IconData? iconData, Color? iconColor, String text) {
    return Container(
      width: 120, // Fixed width for scrollable buttons
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
                builder: (context) => ModifierScreen(
                  allowPerPlatePricing: widget.serviceType.toLowerCase().contains('catering'),
                ),
                settings: const RouteSettings(name: 'ModifierScreen'),
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
                  title: Text('Clear Order'.tr(),style: TextStyle(
                    fontSize: 18, // Smaller font size (default is usually 20-22)
                    fontWeight: FontWeight.bold,
                  ),
                  ),
                  content: Text('Are you sure you want to clear all items from this order?'.tr()),
                  actions: [
                    TextButton(
                      child: Text('Cancel'.tr()),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    TextButton(
                      child: Text('Clear'.tr(), style: TextStyle(color: Colors.red)),
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
                builder: (context) => const TableManagementScreen(),
                settings: const RouteSettings(name: 'TableManagementScreen'),
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
                settings: const RouteSettings(name: 'OrderListScreen'),
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
    );
  }

  // Show Quote Confirmation Dialog
  void _showDeliveryDetailsDialog() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final deliveryChargeController = TextEditingController(text: (orderProvider.deliveryCharge ?? 0.0).toString());
    final deliveryAddressController = TextEditingController(text: orderProvider.deliveryAddress ?? '');
    final deliveryBoyController = TextEditingController(text: orderProvider.deliveryBoy ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delivery Details'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: deliveryChargeController,
                decoration: InputDecoration(labelText: 'Delivery Charge'.tr()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deliveryAddressController,
                decoration: InputDecoration(labelText: 'Delivery Address'.tr()),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: deliveryBoyController,
                decoration: InputDecoration(labelText: 'Delivery Boy'.tr()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final charge = double.tryParse(deliveryChargeController.text) ?? 0.0;
              orderProvider.setDeliveryDetails(
                charge: charge,
                address: deliveryAddressController.text,
                boy: deliveryBoyController.text,
              );
              Navigator.of(ctx).pop();
            },
            child: Text('Save'.tr()),
          ),
        ],
      ),
    );
  }

  void _showQuoteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Save Quotation?'.tr()),
        content: Text('Do you want to save the current items as a quotation?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final orderProvider = Provider.of<OrderProvider>(context, listen: false);
              final result = await orderProvider.saveAsQuote(context);
                if (result['success']) {
                  if(!mounted) return;
                  // Navigate back to the dashboard (root)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }

            },
            child: Text('Save Quote'.tr()),
          ),
        ],
      ),
    );
  }

  // Helper method for custom payment buttons
 Widget _buildPaymentButton(String label, Color color, {Color? textColor, VoidCallback? onTap}) {
  return SizedBox(
    height: 45,
    child: OutlinedButton(
      onPressed: onTap ?? () async {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        
        // Use label instead of text
        final text = label;
        
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
                SnackBar(
                  content: Text('Customer selected: ${selectedPerson.name}'),
                  duration: const Duration(milliseconds: 100),
                ),
              );
            }
          }
          return;
        }

        try {
          // For Cash or Tender button - navigate to TenderScreen
          if (text == "Cash".tr() || text == "Tender".tr()) {
            // Convert cart items to order items
            final orderItems = orderProvider.cartItems.map((menuItem) {
              int parsedId;
              try {
                parsedId = int.parse(menuItem.id);
              } catch (e) {
                // If parsing fails, use a hash of the string as fallback
                parsedId = menuItem.id.hashCode.abs();
                // Ensure it's a valid positive integer
                if (parsedId == 0) parsedId = 1;
              }
              
              return OrderItem(
                id: parsedId,
                name: menuItem.name,
                price: menuItem.price,
                quantity: menuItem.quantity,
                kitchenNote: menuItem.kitchenNote,
              );
            }).toList();

            // Calculate totals based on VAT type
            double itemPricesSum = orderProvider.cartItems.fold(
              0.0, 
              (sum, item) => sum + (item.price * item.quantity)
            );
            
            double subtotal;
            double tax;
            double total;
            
            if (settingsProvider.isVatInclusive) {
              // Inclusive VAT: item prices already include tax
              total = itemPricesSum;
              // Extract tax from the total
              tax = total - (total / (1 + (settingsProvider.taxRate / 100)));
              subtotal = total - tax;
            } else {
              // Exclusive VAT: add tax on top
              subtotal = itemPricesSum;
              tax = subtotal * (settingsProvider.taxRate / 100);
              total = subtotal + tax;
            }

            // Use existing order ID if we're editing an order
            final orderId = widget.existingOrderId;
            
            // Create a temporary Order object for TenderScreen
            final tempOrder = Order(
              id: orderId,
              staffDeviceId: '',
              serviceType: widget.serviceType,
              items: orderItems,
              subtotal: subtotal,
              tax: tax,
              discount: 0.0,
              total: total + (orderProvider.deliveryCharge ?? 0.0), // Include delivery charge in total
              status: 'pending',
              customerId: orderProvider.selectedPerson?.id,
              // Add Delivery Details
              deliveryCharge: orderProvider.deliveryCharge,
              deliveryAddress: orderProvider.deliveryAddress,
              deliveryBoy: orderProvider.deliveryBoy,
              // Add Catering Details
              eventDate: orderProvider.eventDate,
              eventTime: orderProvider.eventTime,
              eventGuestCount: orderProvider.eventGuestCount,
              eventType: orderProvider.eventType,
            );
            
            // Convert to OrderHistory for TenderScreen
            final orderHistory = OrderHistory.fromOrder(tempOrder);

            // Navigate to TenderScreen with the temporary order
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'TenderScreen'),
                builder: (context) => TenderScreen(
                  order: orderHistory,
                  isEdited: orderId != null,
                  taxRate: settingsProvider.taxRate,
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
      child: Text(
        label, 
        style: const TextStyle(color: Colors.black, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

}
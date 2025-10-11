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
    final orientation = MediaQuery.of(context).orientation;
    final isPortrait = orientation == Orientation.portrait;
    
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
            // Kitchen Printer Toggle Button
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
        body: Column(
          children: [
            Expanded(
              child: isPortrait ? _buildPortraitLayout(menuProvider, orderProvider, displayedItems)
                               : _buildLandscapeLayout(menuProvider, orderProvider, displayedItems),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavigationBar(isPortrait),
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
                          : _buildProductGrid(displayedItems, orderProvider, crossAxisCount: 4), // Fewer columns in portrait
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
          height: 300, // Fixed height for order panel in portrait
          child: _buildOrderPanel(orderProvider, isPortrait: true),
        ),
      ],
    );
  }

  // Landscape layout - same as current (horizontal layout)
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
                    : _buildProductGrid(displayedItems, orderProvider, crossAxisCount: 5), // More columns in landscape
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
                
                // Define ideal card width range (min and max)
                const double minCardWidth = 180.0; // Minimum card width
                const double maxCardWidth = 250.0; // Maximum card width
                const double spacing = 8.0;
                
                // Calculate optimal number of columns
                int responsiveColumns = crossAxisCount;
                
                // For desktop screens, calculate columns dynamically
                if (availableWidth > 800) {
                  // Calculate how many columns can fit with ideal card width
                  int maxPossibleColumns = ((availableWidth + spacing) / (minCardWidth + spacing)).floor();
                  int minPossibleColumns = ((availableWidth + spacing) / (maxCardWidth + spacing)).floor();
                  
                  // Use a column count that gives cards between min and max width
                  responsiveColumns = maxPossibleColumns.clamp(minPossibleColumns, 8); // Max 8 columns
                  
                  // Ensure at least 3 columns on desktop
                  if (responsiveColumns < 3) responsiveColumns = 3;
                }
                
                // Calculate actual card dimensions
                final itemWidth = (availableWidth - (spacing * (responsiveColumns + 1))) / responsiveColumns;
                
                // Calculate responsive heights - maintain good proportions
                final imageHeight = itemWidth * 0.6; // 60% of item width for image
                final contentHeight = itemWidth * 0.4; // 40% of item width for content
                final totalItemHeight = imageHeight + contentHeight + 16; // Add padding
                
                // Calculate aspect ratio dynamically
                final aspectRatio = itemWidth / totalItemHeight;
                
                return GridView.builder(
                  padding: EdgeInsets.zero,
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
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                        side: isSelected 
                            ? BorderSide(color: Colors.blue.shade700, width: 1.5)
                            : BorderSide.none,
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
                              child: Padding(
                                padding: EdgeInsets.all((itemWidth * 0.04).clamp(6.0, 12.0)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Item name - responsive font size
                                    Flexible(
                                      flex: 3,
                                      child: Text(
                                        item.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: (itemWidth * 0.09).clamp(12.0, 18.0),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Price
                                    Flexible(
                                      flex: 1,
                                      child: Text(
                                        item.price.toStringAsFixed(3),
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: (itemWidth * 0.06).clamp(9.0, 12.0),
                                        ),
                                      ),
                                    ),
                                    // Status and note indicator
                                    Flexible(
                                      flex: 1,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
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
                                              size: (itemWidth * 0.08).clamp(12.0, 20.0),
                                              color: Colors.blue.shade700,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
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
        cacheWidth: 150, // Reduced cache size
        cacheHeight: 150, // Reduced cache size
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
    memCacheWidth: 150, // Reduced cache size
    memCacheHeight: 150, // Reduced cache size
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
  Widget _buildOrderPanel(OrderProvider orderProvider, {required bool isPortrait}) {
    if (isPortrait) {
      return _buildPortraitOrderPanel(orderProvider);
    } else {
      return _buildLandscapeOrderPanel(orderProvider);
    }
  }

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
                                ],
                              ),
                              Text(orderProvider.tax.toStringAsFixed(3)),
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
          ),
        ],
      ),
    );
  }

  // Landscape order panel - same as current vertical layout
  Widget _buildLandscapeOrderPanel(OrderProvider orderProvider) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

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
            child: Text(
              'Order Items'.tr(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        
                         // Tax row with VAT type badge
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
                              ],
                            ),
                             Text(orderProvider.tax.toStringAsFixed(3)),
                          ],
                        ),
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
                                    onPressed: () async {
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
                                            SnackBar(content: Text('Customer selected: ${selectedPerson.name}'),
                                            duration: const Duration(milliseconds: 100),
                                            ),
                                          );
                                        }
                                      }
                                      return;
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
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
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
      );
    } else {
      // In landscape, show all buttons as before
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            _buildNavButton(Icons.arrow_back_ios, null, ''),
            _buildNavButton(null, null, 'Kitchen note'.tr()),
            _buildNavButton(null, null, 'Clear'.tr()),
            _buildNavButton(null, null, 'Order List'.tr()),
            _buildNavButton(Icons.arrow_forward_ios, null, ''),
          ],
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
    );
  }

  // Updated payment button with better sizing for portrait mode
 Widget _buildPaymentButton(String text, Color color) {
  return SizedBox(
    height: 45,
    child: OutlinedButton(
      onPressed: () async {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        
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
            final orderItems = orderProvider.cartItems.map((menuItem) => 
              OrderItem(
                id: int.parse(menuItem.id),
                name: menuItem.name,
                price: menuItem.price,
                quantity: menuItem.quantity,
                kitchenNote: menuItem.kitchenNote,
              )
            ).toList();

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
              serviceType: widget.serviceType,
              items: orderItems,
              subtotal: subtotal,
              tax: tax,
              discount: 0.0,
              total: total,
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
        text, 
        style: const TextStyle(color: Colors.black, fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

}
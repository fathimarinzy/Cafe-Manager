import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/menu_provider.dart';
import '../providers/order_provider.dart';
import '../models/menu_item.dart';
import '../screens/person_form_screen.dart';
import '../screens/search_person_screen.dart';
import '../screens/modifier_screen.dart';
import '../screens/table_management_screen.dart';
import '../screens/order_confirmation_screen.dart';



class MenuScreen extends StatefulWidget {
  final String serviceType;

  const MenuScreen({super.key, required this.serviceType});

  @override
  MenuScreenState createState() => MenuScreenState();
}

class MenuScreenState extends State<MenuScreen> {
  bool _isLoading = false;
  String _selectedCategory = '';
  String _itemSearchQuery = '';
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _updateTime();
    
    // Set the current service type in OrderProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false)
          .setCurrentServiceType(widget.serviceType);
    });
  }

  // Function to update the current time every second
  void _updateTime() {
    Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateFormat('hh:mm a').format(DateTime.now());
        });
      }
    });
  }
  

  Future<void> _loadMenu() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      await menuProvider.fetchMenu();
      await menuProvider.fetchCategories();
      if (menuProvider.categories.isNotEmpty) {
        setState(() {
          _selectedCategory = menuProvider.categories.first;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load menu. Please try again.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = Provider.of<MenuProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    // First get items by category
    List<MenuItem> displayedItems = _selectedCategory.isNotEmpty
        ? menuProvider.getItemsByCategory(_selectedCategory)
        : menuProvider.items;

    // Then filter by search query if it exists
    if (_itemSearchQuery.isNotEmpty) {
      // When searching items, we want to search across ALL items, not just the selected category
      displayedItems = menuProvider.items.where((item) {
        return item.name.toLowerCase().contains(_itemSearchQuery.toLowerCase());
      }).toList();
    }

    return Scaffold(
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.black, size: 20),
                const SizedBox(width: 4),
                Text(
                  _currentTime,
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.0),
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
            _buildNavButton(null, null, 'Discount'),
            _buildNavButton(null, null, 'Sales hold list'),
            _buildNavButton(null, null, 'Hold'),
            _buildNavButton(null, null, 'Memo'),
            _buildNavButton(null, null, 'Modifier'),
            _buildNavButton(null, null, 'Kitchen note'),
            _buildNavButton(null, null, 'Clear'),
            _buildNavButton(null, null, 'Remove'),
            _buildNavButton(null, null, 'Amount split'),
            _buildNavButton(null, null, 'Item split'),
            _buildNavButton(null, null, 'Order list'),
            _buildNavButton(null, null, 'Tables'),
            _buildNavButton(Icons.arrow_forward_ios, null, ''),
          ],
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
          if (text == 'Modifier') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ModifierScreen()
              ),
            );
          } else if (text == 'Clear') {
            // Clear the current cart with visual feedback
            final orderProvider = Provider.of<OrderProvider>(context, listen: false);
            
            // Only show the confirmation if there are items in the cart
            if (orderProvider.cartItems.isNotEmpty) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Order',style: TextStyle(
                    fontSize: 18, // Smaller font size (default is usually 20-22)
                    fontWeight: FontWeight.bold,
                  ),
                  ),
                  content: const Text('Are you sure you want to clear all items from this order?'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    TextButton(
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        orderProvider.clearCart();
                        Navigator.of(ctx).pop();
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Order cleared successfully'),
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
                const SnackBar(
                  content: Text('Order is already empty'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          } else if (text == 'Tables' ) {
            // Handle Tables navigation
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TableManagementScreen()
              ),
            );
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
                style: TextStyle(fontSize: 12, color: Colors.black),
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
                hintText: "Search Menu...",
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: const [],
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
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFFD4E6FF) : Colors.transparent,
                    border: Border(
                     left: BorderSide(
                        color: isSelected ? (Colors.blue[900] ?? Colors.blue) : Colors.transparent,
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
        child: GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.8,
            crossAxisSpacing: 13,
            mainAxisSpacing: 13,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, index) {
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                onTap: items[index].isAvailable
                    ? () {
                        orderProvider.addToCart(items[index]);
                      }
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          child: _buildItemImage(items[index]),
                          ),  
                          if (!items[index].isAvailable)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              ),
                              child: const Center(
                                child: Text(
                                  'Out of stock',
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
                            items[index].name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            items[index].price.toStringAsFixed(3),
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 10,
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              items[index].isAvailable ? 'Available' : 'Out of stock',
                              style: TextStyle(
                                color: items[index].isAvailable ? Colors.green : Colors.red,
                                fontSize: 10,
                              ),
                            ),
                          )
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

  // Handle base64 images
  if (item.imageUrl.startsWith('data:image')) {
    try {
      // Parse base64 data
      final parts = item.imageUrl.split(',');
      if (parts.length != 2) {
        return Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image));
      }
      
      String base64String = parts[1];
      
      // Clean and prepare base64 data
      base64String = base64String.replaceAll(RegExp(r'\s+'), '');
      base64String = base64String.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
      
      // Fix padding
      int padding = (4 - (base64String.length % 4)) % 4;
      base64String = base64String.padRight(base64String.length + padding, '=');
      
      // Decode and display
      final decodedBytes = base64Decode(base64String);
      return Image.memory(
        decodedBytes,
        fit: BoxFit.cover,
      );
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image));
    }
  }
  
  // Handle network images
  return CachedNetworkImage(
    imageUrl: item.imageUrl,
    fit: BoxFit.cover,
    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    errorWidget: (context, url, error) {
      debugPrint('Error loading image: $error');
      return Container(
        color: Colors.grey.shade300,
        child: const Center(child: Icon(Icons.broken_image)),
      );
    },
  );
}

  Widget _buildOrderPanel(OrderProvider orderProvider) {
    return Container(
      width: 350,
      color: Colors.white,
      child: SingleChildScrollView(
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
                'Order Items',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Order items list or empty cart message
            orderProvider.cartItems.isEmpty
                ? _buildEmptyCartMessage()
                : ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: orderProvider.cartItems.length,
                    itemBuilder: (ctx, index) {
                      final item = orderProvider.cartItems[index];
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                            // Item name and price
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.price.toStringAsFixed(3)} × ${item.quantity}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity adjustment and controls
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
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
                                    minimumSize: const Size(24, 24),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: () {
                                    orderProvider.updateItemQuantity(item.id, item.quantity + 1);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(24, 24),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  (item.price * item.quantity).toStringAsFixed(3),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                                  onPressed: () {
                                    orderProvider.removeItem(item.id);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(24, 24),
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
                    Text('Sub total', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(orderProvider.subtotal.toStringAsFixed(3), style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Additional charges rows
                _buildSummaryRow('Tax amount', '0.000'),
                _buildSummaryRow('Item discount', '0.000'),
                _buildSummaryRow('Bill discount', '0.000'),
                _buildSummaryRow('Delivery charge', '0.000'),
                _buildSummaryRow('Surcharge', '0.000'),
                
                const SizedBox(height: 8),
                // Grand total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand total', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(orderProvider.total.toStringAsFixed(3), style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                
                // const SizedBox(height: 16),
                
                // // NA input field
                // TextField(
                //   decoration: InputDecoration(
                //     border: OutlineInputBorder(),
                //     labelText: 'NA',
                //   ),
                // ),
                
                const SizedBox(height: 10),
                
                // Date visited, Count visited, Point
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date visited', style: TextStyle(fontSize: 11)),
                          const SizedBox(height: 6),
                          Container(
                            height: 40,
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                "${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}",
                                  style: TextStyle(fontSize: 10),
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
                          Text('Count visited', style: TextStyle(fontSize: 11)),
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
                          Text('Point', style: TextStyle(fontSize: 11)),
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
                            icon: Icon(Icons.person_outline, color: Colors.blue[900]),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PersonFormScreen()
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.search, color: Colors.blue[900]),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SearchPersonScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Payment buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPaymentButton('Cash', Colors.grey.shade100),
                    // _buildPaymentButton('Tender', Colors.grey.shade100),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPaymentButton('Terminal credit', Colors.grey.shade100),
                    _buildPaymentButton('Order', Colors.grey.shade100),
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
          'Your cart is empty',
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
  if (text == "Tender") {
    // Skip rendering the Tender button
    return const SizedBox.shrink();
  }
  
  return SizedBox(
    width: 130,
    height: 50,
    child: OutlinedButton(
      onPressed: () {
        if (text == "Order") {
          final orderProvider = Provider.of<OrderProvider>(context, listen: false);
          
          // Check if cart is empty
          if (orderProvider.cartItems.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please add items to your order')),
            );
            return;
          }
          
          // Navigate to order confirmation screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OrderConfirmationScreen(
                serviceType: widget.serviceType,
              ),
            ),
          );
        } else if (text == "Cash") {
          final orderProvider = Provider.of<OrderProvider>(context, listen: false);
          
          // Check if cart is empty
          if (orderProvider.cartItems.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please add items to your order')),
            );
            return;
          }
          
          // Navigate to order confirmation screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OrderConfirmationScreen(
                serviceType: widget.serviceType,
              ),
            ),
          );
        }
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: color,
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Text(text, style: TextStyle(color: Colors.black)),
    ),
  );
  }
}
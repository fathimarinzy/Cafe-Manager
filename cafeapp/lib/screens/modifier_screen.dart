import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../providers/menu_provider.dart';
import '../models/menu_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/sync_service.dart';
import '../repositories/local_menu_repository.dart';
import '../services/connectivity_service.dart';

class ModifierScreen extends StatefulWidget {
  const ModifierScreen({super.key});

  @override
  State<ModifierScreen> createState() => _ModifierScreenState();
}

class _ModifierScreenState extends State<ModifierScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  
  String _selectedCategory = '';
  final _categoryController = TextEditingController();
  
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isAvailable = true;
  bool _isAddingNewCategory = false;
  
  MenuItem? _editingItem;
  
  // Properties for image handling
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isImageLoading = false;
  String? _base64Image;

// Add these properties for offline functionality
  bool _isOffline = false;
  SyncStatus _syncStatus = SyncStatus.idle;
  StreamSubscription? _syncSubscription;
  StreamSubscription? _connectivitySubscription;

    // Create instances of the services
  final ConnectivityService _connectivityService = ConnectivityService();
  final LocalMenuRepository _localRepo = LocalMenuRepository();
  

  
  @override
  void initState() {
    super.initState();
    
    // Fetch data once when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      menuProvider.fetchMenu();
      menuProvider.fetchCategories().then((_) {
        if (menuProvider.categories.isNotEmpty && mounted) {
          setState(() {
            _selectedCategory = menuProvider.categories.first;
          });
        }
      });
       // Check if we're offline
    setState(() {
      _isOffline = menuProvider.isOfflineMode;
    });
          
      // Listen for offline status changes
      _connectivityService.initialize();
      _connectivitySubscription = _connectivityService.connectivityStream.listen((isConnected) {
        if (mounted) {
          setState(() {
            _isOffline = !isConnected;
          });
        }
      });
    
    // Listen for sync status changes
    _syncStatus = menuProvider.syncStatus;
    _syncSubscription = menuProvider.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
        });
      }
    });

    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _syncSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
  
  void _resetForm() {
    _nameController.clear();
    _priceController.clear();
    _categoryController.clear();
    setState(() {
      _isAvailable = true;
      _editingItem = null;
      _isAddingNewCategory = false;
      _selectedImage = null;
      _base64Image = null;
      
      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      if (menuProvider.categories.isNotEmpty) {
        _selectedCategory = menuProvider.categories.first;
      } else {
        _selectedCategory = '';
      }
    });
  }
  
  void _prepareForEdit(MenuItem item) {
    setState(() {
      _editingItem = item;
      _nameController.text = item.name;
      _priceController.text = item.price.toString();
      _selectedCategory = item.category;
      _isAvailable = item.isAvailable;
      _isAddingNewCategory = false;
      _selectedImage = null;
      
      // If the image is a base64 image, store it for later use
      if (item.imageUrl.startsWith('data:image')) {
        _base64Image = item.imageUrl;
      } else {
        _base64Image = null;
      }
    });
  }

  // Improved image picker with better file handling
  Future<void> _pickImage() async {
    setState(() {
      _isImageLoading = true;
    });
    
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 25, // Lower quality for smaller size
        maxWidth: 300,
        maxHeight: 300,
      );
      
      if (!mounted) return;
      
      if (pickedFile != null) {
        // Convert XFile to File
        final File imageFile = File(pickedFile.path);
        
        // Check if file exists before using it
        if (await imageFile.exists()) {
          if (!mounted) return;
          setState(() {
            _selectedImage = imageFile;
            _base64Image = null;
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access the selected image')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
      }
    }
  }

  // Updated camera function with better file handling
  Future<void> _takePhoto() async {
    setState(() {
      _isImageLoading = true;
    });
    
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 25, // Lower quality for smaller size
        maxWidth: 300,
        maxHeight: 300,
      );
      
      if (!mounted) return;
      
      if (pickedFile != null) {
        // Convert XFile to File
        final File imageFile = File(pickedFile.path);
        
        // Check if file exists before using it
        if (await imageFile.exists()) {
          if (!mounted) return;
          setState(() {
            _selectedImage = imageFile;
            _base64Image = null;
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access the captured photo')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
      }
    }
  }

  // Improved base64 encoding function with better error handling
  String? _getBase64Image() {
    if (_selectedImage == null) return _base64Image;
    
    try {
      // Check if file exists and is readable
      if (!_selectedImage!.existsSync()) {
        debugPrint('Image file does not exist: ${_selectedImage!.path}');
        return null;
      }
      
      // Get file size before encoding
      final fileSize = _selectedImage!.lengthSync();
      
      // If file is too large, resize it
      if (fileSize > 500000) { // 500KB limit
        debugPrint('WARNING: Image file is very large ($fileSize bytes), will be compressed');
      }
      
      // Read file as bytes
      final List<int> imageBytes = _selectedImage!.readAsBytesSync();
      
      // Generate a proper base64 string
      final base64String = base64Encode(imageBytes);
      
      // Create image data URL
      final imageDataUrl = 'data:image/jpeg;base64,$base64String';
      
      return imageDataUrl;
    } catch (e) {
      debugPrint('Error encoding image to base64: $e');
      return null;
    }
  }
  Widget _buildSyncStatusIndicator() {
  // If we're not offline, don't show anything
  if (!_isOffline && _syncStatus != SyncStatus.syncing) {
    return const SizedBox.shrink();
  }
  
  // Choose the right icon and color based on status
  IconData icon;
  Color color;
  String message;
  
  if (_isOffline) {
    icon = Icons.cloud_off;
    color = Colors.orange;
    message = "Offline Mode";
  } else if (_syncStatus == SyncStatus.syncing) {
    icon = Icons.sync;
    color = Colors.blue;
    message = "Syncing...";
  } else if (_syncStatus == SyncStatus.error) {
    icon = Icons.error_outline;
    color = Colors.red;
    message = "Sync Error";
  } else if (_syncStatus == SyncStatus.completed) {
    icon = Icons.check_circle_outline;
    color = Colors.green;
    message = "Sync Complete";
  } else {
    return const SizedBox.shrink();
  }
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withAlpha(128)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
         Text(
          message,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        // Add a sync button if we're offline
        if (_isOffline)
          TextButton(
            onPressed: () {
              final menuProvider = Provider.of<MenuProvider>(context, listen: false);
              menuProvider.syncChanges();
            },
            child: const Text("Sync when online", style: TextStyle(fontSize: 12)),
          ),
      ],
    ),
  );
}

// Add this method to build the pending changes indicator
Widget _buildPendingChangesIndicator() {
  // Only show this if we have offline changes
  if (!_isOffline && _syncStatus != SyncStatus.syncing) {
    return const SizedBox.shrink();
  }
  
  return FutureBuilder<List<Map<String, dynamic>>>(
      future: _localRepo.getPendingOperations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
      
      final pendingCount = snapshot.data!.length;
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Text(
          '$pendingCount pending ${pendingCount == 1 ? 'change' : 'changes'}',
          style: TextStyle(
            color: Colors.amber.shade900,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  );
}
      

  // Improved image from base64 function with better error handling
  Widget _buildImageFromBase64(String base64ImageData) {
    try {
      // Basic validation of base64 data
      if (!base64ImageData.startsWith('data:image')) {
        return const Icon(Icons.broken_image, color: Colors.red);
      }
      
      final parts = base64ImageData.split(',');
      if (parts.length != 2) {
        return const Icon(Icons.broken_image, color: Colors.red);
      }
      
      // Clean and prepare base64 string
      String base64Content = parts[1].trim();
      base64Content = base64Content.replaceAll(RegExp(r'\s+'), '');
      
      // Add padding if needed
      int paddingNeeded = (4 - (base64Content.length % 4)) % 4;
      base64Content = base64Content.padRight(base64Content.length + paddingNeeded, '=');
      
      try {
        // Decode base64 data
        final imageData = base64Decode(base64Content);
        
        // Create image widget with key for consistent rendering
        return Image.memory(
          imageData,
          fit: BoxFit.cover,
          key: ValueKey(base64ImageData.hashCode),
          gaplessPlayback: true,
          cacheWidth: 200, // Specify cache size to improve performance
          cacheHeight: 200,
        );
      } catch (e) {
        return const Icon(Icons.broken_image, color: Colors.orange);
      }
    } catch (e) {
      return const Icon(Icons.broken_image, color: Colors.red);
    }
  }

  // Improved method to build image in the list
  Widget _buildImageForListItem(MenuItem item) {
    // No image case
    if (item.imageUrl.isEmpty) {
      return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey));
    }

    // Add a ValueKey for better Flutter rendering and caching
    final imageKey = ValueKey('${item.id}_image');

    // Handle base64 images
    if (item.imageUrl.startsWith('data:image')) {
      return _buildImageFromBase64(item.imageUrl);
    } else if (item.imageUrl.startsWith('file://')) {
      // Handle file:/// URLs
      try {
        final file = File(item.imageUrl.replaceFirst('file://', ''));
        if (!file.existsSync()) {
          return const Icon(Icons.broken_image, color: Colors.red);
        }
        return Image.file(
          file,
          fit: BoxFit.cover,
          key: imageKey,
          gaplessPlayback: true,
          cacheWidth: 100,
          cacheHeight: 100,
        );
      } catch (e) {
        return const Icon(Icons.broken_image, color: Colors.red);
      }
    } else {
      // Handle network images
      return CachedNetworkImage(
        imageUrl: item.imageUrl,
        fit: BoxFit.cover,
        key: imageKey,
        fadeInDuration: const Duration(milliseconds: 0), // No fade animation
        fadeOutDuration: const Duration(milliseconds: 0),
        memCacheWidth: 100, // Limit memory cache size
        memCacheHeight: 100,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 20, 
            height: 20, 
            child: CircularProgressIndicator(strokeWidth: 2)
          ),
        ),
        errorWidget: (context, url, error) {
          return const Icon(Icons.broken_image, color: Colors.red);
        },
      );
    }
  }

  void _showDeleteConfirmation(MenuItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete ${item.name}?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      _deleteItem(item);
    }
  }

  
  void _deleteItem(MenuItem item) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text("Deleting item...")
        ],
      ),
    ),
  );
  
  bool success = false;
  String errorMessage = 'Failed to delete item. Please try again.';
  
  try {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    success = await menuProvider.deleteMenuItem(item.id);
    
    // Force refresh menu and categories on success
    if (success) {
      await menuProvider.fetchMenu();
      await menuProvider.fetchCategories();
    }
  } catch (e) {
    success = false;
    // If the error contains "foreign key constraint", provide a clearer message
    if (e.toString().toLowerCase().contains('foreign key') || 
        e.toString().toLowerCase().contains('constraint')) {
      errorMessage = 'This item cannot be deleted because it is used in existing orders.';
    } else {
      errorMessage = 'Error: ${e.toString()}';
    }
    debugPrint('Exception during delete: $e');
  }
  
  if (!mounted) return;
  
  // Close the loading dialog
  Navigator.of(context).pop();
  
  // Show result message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(success ? 'Item deleted successfully' : errorMessage),
      backgroundColor: success ? Colors.green : Colors.red,
      duration: const Duration(seconds: 3),
      action: success ? null : SnackBarAction(
        label: 'Dismiss',
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ),
  );
  
  // Force UI refresh
  if (success) {
    setState(() {
      // Force rebuild by refreshing state
    });
  }
}

  void _toggleCategoryInput(bool isAdding) {
    setState(() {
      _isAddingNewCategory = isAdding;
      if (isAdding) {
        _categoryController.text = '';
      } else {
        final menuProvider = Provider.of<MenuProvider>(context, listen: false);
        if (menuProvider.categories.isNotEmpty) {
          _selectedCategory = menuProvider.categories.first;
        }
      }
    });
  }

  // Improved save function with more robust image handling
  void _saveItemToDatabase() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate category
    if (_selectedCategory.isEmpty && !_isAddingNewCategory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    
    // Show saving dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Saving item...")
          ],
        ),
      ),
    );

    // Handle category
    String categoryToUse;
    if (_isAddingNewCategory && _categoryController.text.isNotEmpty) {
      categoryToUse = _categoryController.text.trim();
      try {
        final categoryAdded = await menuProvider.addCategory(categoryToUse);
        if (!categoryAdded) {
          throw Exception("Failed to add category");
        }
        await menuProvider.fetchCategories();
        _selectedCategory = categoryToUse;
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add category: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      categoryToUse = _selectedCategory;
    }

    // Get image data with robust fallbacks
    String imageUrl = '';
    
    // Case 1: New image selected - encode to base64
    if (_selectedImage != null) {
      final encodedImage = _getBase64Image();
      if (encodedImage != null && encodedImage.isNotEmpty) {
        imageUrl = encodedImage;
      } else {
        // Close dialog and show error
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to process image. Please try a different one.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } 
    // Case 2: Editing item with existing image
    else if (_editingItem?.imageUrl.isNotEmpty == true) {
      imageUrl = _editingItem!.imageUrl;
    }
    // Case 3: Using base64 image from state
    else if (_base64Image != null && _base64Image!.isNotEmpty) {
      imageUrl = _base64Image!;
    }
    // New item with no image - require image
    // else {
    //   if (!mounted) return;
    //   Navigator.of(context).pop();
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(
    //       content: Text('Please select an image'),
    //       backgroundColor: Colors.red,
    //     ),
    //   );
    //   return;
    // }

    // Create the item with proper data
    final item = MenuItem(
      id: _editingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      price: double.parse(_priceController.text),
      category: categoryToUse,
      imageUrl: imageUrl,
      isAvailable: _isAvailable,
    );

    // Save to database
    bool success = false;
    try {
      if (_editingItem == null) {
        await menuProvider.addMenuItem(item);
      } else {
        await menuProvider.updateMenuItem(item);
      }
      success = true;
    } catch (e) {
      success = false;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // Close dialog

    // Show result message
    final message = _editingItem == null ? 'Item added successfully' : 'Item updated successfully';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? message : 'Failed to save item. Please try again.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _resetForm();
      // Refresh data
      try {
        await menuProvider.fetchCategories();
        await menuProvider.fetchMenu();
      } catch (e) {
        // Ignore errors
      }
    }
  }

  // Helper for image error states
  Widget _buildErrorImagePreview(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, size: 30, color: Colors.red),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: Colors.red),
          ),
        ],
      ),
    );
  }

  // Improved image preview builder
  Widget _buildImagePreview() {
    // Show selected image file
    if (_selectedImage != null) {
      try {
        if (!_selectedImage!.existsSync()) {
          return _buildErrorImagePreview('Image file not found');
        }
        
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            _selectedImage!,
            fit: BoxFit.contain,
            key: ValueKey(_selectedImage!.path), // Add key to prevent rebuilds
            gaplessPlayback: true, // Add this to prevent flickering
            cacheWidth: 300, // Specify cache dimensions for better performance
            cacheHeight: 300,
          ),
        );
      } catch (e) {
        return _buildErrorImagePreview('Error showing image');
      }
    }
    
    // Show base64 image from state
    if (_base64Image != null && _base64Image!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImageFromBase64(_base64Image!),
      );
    }
    
    // URL image from editing item
    if (_editingItem?.imageUrl.isNotEmpty == true && 
        !(_editingItem!.imageUrl.startsWith('data:image'))) {
      
      // Handle file:/// URLs
      if (_editingItem!.imageUrl.startsWith('file:///')) {
        try {
          final file = File(_editingItem!.imageUrl.replaceFirst('file://', ''));
          if (!file.existsSync()) {
            return _buildErrorImagePreview('Image file not found');
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              fit: BoxFit.contain,
              key: ValueKey(file.path),
              gaplessPlayback: true,
            ),
          );
        } catch (e) {
          return _buildErrorImagePreview('Invalid file path');
        }
      }
      
      // Network image
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: _editingItem!.imageUrl,
          fit: BoxFit.contain,
          key: ValueKey(_editingItem!.imageUrl),
          fadeInDuration: const Duration(milliseconds: 0),
          fadeOutDuration: const Duration(milliseconds: 0),
          placeholder: (context, url) => const Center(
            child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) {
            return _buildErrorImagePreview('Failed to load image');
          },
        ),
      );
    }
    
    // No image selected
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 4),
          Text(
            'No image selected',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = Provider.of<MenuProvider>(context);
    
    if (_selectedCategory.isEmpty && menuProvider.categories.isNotEmpty) {
      _selectedCategory = menuProvider.categories.first;
    }

    List<MenuItem> displayedItems = [];
    if (_selectedCategory.isNotEmpty && menuProvider.categories.contains(_selectedCategory)) {
      displayedItems = menuProvider.getItemsByCategory(_selectedCategory);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifiers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
         actions: [
        // Add sync status indicator to the app bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildSyncStatusIndicator(),
        ),
        
        // Add pending changes indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildPendingChangesIndicator(),
        ),
        
        // Add manual sync button if we're online
        if (!_isOffline)
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync changes',
            onPressed: () {
              menuProvider.syncChanges();
            },
          ),
      ],

      ),
      // Make the body a SingleChildScrollView that adjusts for keyboard
      body: SafeArea(
        child: Row(
          children: [
            // Menu items list (left side)
            Expanded(
              flex: 2,
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category dropdown for the left panel
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        value: menuProvider.categories.contains(_selectedCategory) ? _selectedCategory : null,
                        items: menuProvider.categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                            });     
                          }
                        },
                        hint: const Text('Select a category'),
                      ),
                    ),

                    // Items list - Improved version
                    Expanded(
                      child: _selectedCategory.isEmpty || !menuProvider.categories.contains(_selectedCategory) ? 
                        const Center(child: Text('No category selected')) :
                         displayedItems.isEmpty ?
                        const Center(child: Text('No items in this category')) :
                        ListView.builder(
                          key: _listKey,
                          itemCount: displayedItems.length,
                          itemBuilder: (ctx, index) {
                            final item = displayedItems[index];
                             // Add a small indicator for offline items
                            //  final bool isOfflineItem = item.id.startsWith('local_');
                            
                            return ListTile(
                              key: ValueKey('item_${item.id}'),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7.0),
                                  child: _buildImageForListItem(item),
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.price.toStringAsFixed(2)),
                                  Text(
                                    item.isAvailable ? 'Available' : 'Out of stock',
                                    style: TextStyle(
                                      color: item.isAvailable ? Colors.green : Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _prepareForEdit(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteConfirmation(item),
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
            ),

            // Form for adding/editing (right side)
            Expanded(
              flex: 3,
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  // Make the form scrollable to handle keyboard
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editingItem == null ? 'Add New Item' : 'Edit Item',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Name field
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Price field
                          TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a price';
                              }
                              try {
                                double.parse(value);
                              } catch (e) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Category field - either dropdown or text input based on state
                          _isAddingNewCategory
                            ? Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _categoryController,
                                      decoration: const InputDecoration(
                                        labelText: 'New Category',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a category name';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => _toggleCategoryInput(false),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'Category',
                                        border: OutlineInputBorder(),
                                      ),
                                      value: menuProvider.categories.contains(_selectedCategory) ? _selectedCategory : null,
                                      items: menuProvider.categories.map((category) {
                                        return DropdownMenuItem<String>(
                                          value: category,
                                          child: Text(category),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedCategory = value;
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a category';
                                        }
                                        return null;
                                      },
                                      hint: const Text('Select a category'),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () => _toggleCategoryInput(true),
                                    tooltip: 'Add new category',
                                  ),
                                ],
                              ),

                          const SizedBox(height: 16),

                          // Image section with upload buttons only
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                               children: [
                              const Text(
                                'Item Image (Optional)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                               if (_selectedImage != null || _base64Image != null)
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                    label: const Text('Remove Image', style: TextStyle(color: Colors.red)),
                                    onPressed: () {
                                      setState(() {
                                        _selectedImage = null;
                                        _base64Image = null;
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                              
                              // Image upload buttons
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.photo_library),
                                    label: const Text('Gallery'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _takePhoto,
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Camera'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Image preview - DECREASED HEIGHT
                              const SizedBox(height: 12),
                              Container(
                                height: 120, // Decreased size
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _isImageLoading ? 
                                  const Center(child: CircularProgressIndicator()) :
                                   ((_selectedImage == null && _base64Image == null && (_editingItem?.imageUrl.isEmpty ?? true)) ?
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.image_outlined, size: 40, color: Colors.grey[400]),
                                        const SizedBox(height: 4),
                                        Text(
                                          'No image selected',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '(Images are optional)',
                                          style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                  ) : 
                                  _buildImagePreview()),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Availability switch
                          Row(
                            children: [
                              const Text('Available'),
                              Switch(
                                value: _isAvailable,
                                onChanged: (value) {
                                  setState(() {
                                    _isAvailable = value;
                                  });
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 32), // Add extra space at bottom

                          // Form buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _resetForm,
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _saveItemToDatabase,
                                child: Text(_editingItem == null ? 'Add Item' : 'Update Item'),
                              ),
                            ],
                          ),
                          // Add extra padding at the bottom to ensure enough space for keyboard
                          SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 320 : 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Add resizeToAvoidBottomInset to make sure the keyboard doesn't overlap content
      resizeToAvoidBottomInset: true,
    );
  }
}
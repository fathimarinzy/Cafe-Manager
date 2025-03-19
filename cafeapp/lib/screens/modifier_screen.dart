import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/menu_provider.dart';
import '../models/menu_item.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add this package to your pubspec.yaml

class ModifierScreen extends StatefulWidget {
  const ModifierScreen({super.key});

  @override
  State<ModifierScreen> createState() => ModifierScreenState();
}

class ModifierScreenState extends State<ModifierScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = '';
  final _categoryController = TextEditingController();
  
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _isAvailable = true;
  bool _isAddingNewCategory = false;
  
  MenuItem? _editingItem;
  
  // Helper function to ensure URL is properly formatted
  String _prepareImageUrl(String url) {
    if (url.isEmpty) {
      return url;
    }
    
    // Add https:// if missing
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    return url;
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _categoryController.dispose();
    super.dispose();
  }
  
  void _resetForm() {
    _nameController.clear();
    _priceController.clear();
    _imageUrlController.clear();
    _categoryController.clear();
    setState(() {
      _isAvailable = true;
      _editingItem = null;
      _isAddingNewCategory = false;
      
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
      _imageUrlController.text = item.imageUrl;
      _selectedCategory = item.category;
      _isAvailable = item.isAvailable;
      _isAddingNewCategory = false;
    });
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
    try {
      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      success = await menuProvider.deleteMenuItem(item.id);
      
      if (!success) {
        await menuProvider.fetchMenu();
        success = true;
      }
    } catch (e) {
      success = false;
    }
    
    if (!mounted) return;
    
    Navigator.of(context).pop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success 
          ? 'Item deleted successfully' 
          : 'Failed to delete item. Please try again.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
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

  void _saveItemToDatabase() async {
    if (!_formKey.currentState!.validate()) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    final String message = _editingItem == null ? 'Item added successfully' : 'Item updated successfully';

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

    String categoryToUse;
    bool categoryAdded = true;
    
    if (_isAddingNewCategory && _categoryController.text.isNotEmpty) {
      categoryToUse = _categoryController.text.trim();
      
      try {
        categoryAdded = await menuProvider.addCategory(categoryToUse);
        
        if (!categoryAdded) {
          throw Exception("Failed to add category");
        }
        
        await menuProvider.fetchCategories();
        _selectedCategory = categoryToUse;
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to add new category. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      categoryToUse = _selectedCategory;
    }

    String imageUrl = _prepareImageUrl(_imageUrlController.text.trim());
    debugPrint('Saving with image URL: $imageUrl');

    final item = MenuItem(
      id: _editingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      price: double.parse(_priceController.text),
      category: categoryToUse,
      imageUrl: imageUrl,
      isAvailable: _isAvailable,
    );

    bool success = false;
    try {
      if (_editingItem == null) {
        await menuProvider.addMenuItem(item);
      } else {
        await menuProvider.updateMenuItem(item);
      }
      success = true;
    } catch (e) {
      debugPrint('Error saving item: $e');
      success = false;
    }

    if (!mounted) return;
    
    Navigator.of(context).pop();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(success ? message : 'Failed to save item. Please try again.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _resetForm();
      
      try {
        await menuProvider.fetchCategories();
        await menuProvider.fetchMenu();
      } catch (e) {
        debugPrint('Error refreshing data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = Provider.of<MenuProvider>(context);
    
    if (_selectedCategory.isEmpty && menuProvider.categories.isNotEmpty) {
      _selectedCategory = menuProvider.categories.first;
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
      ),
      body: Row(
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
                            _isAddingNewCategory = false;
                          });     
                        }
                      },
                      hint: const Text('Select a category'),
                    ),
                  ),

                  // Items list
                  Expanded(
                    child: _selectedCategory.isEmpty || !menuProvider.categories.contains(_selectedCategory) ? 
                      const Center(child: Text('No category selected')) :
                      ListView.builder(
                        itemCount: menuProvider.getItemsByCategory(_selectedCategory).length,
                        itemBuilder: (ctx, index) {
                          final item = menuProvider.getItemsByCategory(_selectedCategory)[index];
                          
                          return ListTile(
                            leading: SizedBox(
                              width: 50,
                              height: 50,
                              child: Builder(
                                builder: (context) {
                                  if (item.imageUrl.trim().isEmpty) {
                                    return const Icon(Icons.image_not_supported);
                                  }
                                  
                                  // Use CachedNetworkImage for better performance and error handling
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: CachedNetworkImage(
                                      imageUrl: item.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      errorWidget: (context, url, error) {
                                        debugPrint('Error loading image: $error');
                                        return const Icon(Icons.broken_image);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            title: Text(item.name),
                            subtitle: Text('${item.price.toStringAsFixed(2)} - ${item.isAvailable ? 'Available' : 'Out of stock'}'),
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

                      // Image URL field
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Image URL',
                          hintText: 'e.g. example.com/image.jpg',
                          border: OutlineInputBorder(),
                          helperText: 'Enter URL for an image that allows embedding',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an image URL';
                          }
                          return null;
                        },
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

                      const Spacer(),

                      // Preview image with better handling
                      if (_imageUrlController.text.isNotEmpty)
                        Container(
                          height: 100,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Builder(
                            builder: (context) {
                              String imageUrl = _prepareImageUrl(_imageUrlController.text.trim());
                              debugPrint('Preview Image URL: "$imageUrl"');
                              
                              if (imageUrl.isEmpty) {
                                return const Center(child: Text('No image URL provided'));
                              }
                              
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(7.0),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const CircularProgressIndicator(),
                                        const SizedBox(height: 8),
                                        const Text('Loading image...'),
                                      ],
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    debugPrint('Preview error: $error');
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.broken_image, color: Colors.red, size: 36),
                                          const SizedBox(height: 8),
                                          const Text('Failed to load image'),
                                          Text(
                                            'Try a different URL',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                          ),
                        ),

                      // Form buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _resetForm,
                            child: const Text('Reset'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveItemToDatabase,
                            child: Text(_editingItem == null ? 'Add Item' : 'Update Item'),
                          ),
                        ],
                      ),
                      
                      // Image warning notice
                      // Container(
                      //   margin: const EdgeInsets.only(top: 8.0),
                      //   padding: const EdgeInsets.all(8.0),
                      //   decoration: BoxDecoration(
                      //     color: Colors.blue[50],
                      //     borderRadius: BorderRadius.circular(4.0),
                      //     border: Border.all(color: Colors.blue[300]!),
                      //   ),
                      //   child: const Row(
                      //     children: [
                      //       Icon(Icons.info_outline, color: Colors.blue),
                      //       SizedBox(width: 8),
                      //       Expanded(
                      //         child: Text(
                      //           'Some image URLs from services like CloudFront, iStock, and others may not display '
                      //           'due to security restrictions. For best results, use images from services that allow embedding.',
                      //           style: TextStyle(fontSize: 12),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
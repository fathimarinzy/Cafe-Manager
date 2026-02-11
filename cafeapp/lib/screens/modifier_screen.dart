// import 'package:cafeapp/repositories/local_order_repository.dart';
import 'package:cafeapp/services/excel_import_service.dart';
import 'package:cafeapp/utils/camera_helper.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../providers/menu_provider.dart';
import '../models/menu_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_localization.dart';
import '../utils/keyboard_utils.dart';


class ModifierScreen extends StatefulWidget {
  final bool allowPerPlatePricing;

  const ModifierScreen({super.key, this.allowPerPlatePricing = false});

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
  final _nameFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _categoryFocus = FocusNode();
  bool _isAvailable = true;
  bool _isAddingNewCategory = false;
  bool _isTaxExempt = false;
  bool _isPerPlate = false; // NEW

  
  MenuItem? _editingItem;
  
  // Properties for image handling
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isImageLoading = false;
  String? _base64Image;
  
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
    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _nameFocus.dispose();
    _priceFocus.dispose();
    _categoryFocus.dispose();
    super.dispose();
  }
  /// Export menu with proper permission handling and user feedback
Future<void> exportMenuWithPermissionHandling(
  BuildContext context,
  List<MenuItem> items,
) async {
  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text("Preparing export...")),
        ],
      ),
    ),
  );

  try {
    // Call the export function (which now handles permissions internally)
    final result = await ExcelImportService.exportMenuItemsWithImages(items);

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    if (result == null) {
      _showErrorDialog(context, 'Export failed', 'Unable to export menu items.');
      return;
    }

    // Check if export was successful
    if (result['success'] == true) {
      // SUCCESS!
      _showSuccessDialog(
        context,
        'Export Successful!',
        'Exported ${result['itemsExported']} items\n'
        '${result['imagesExported']} images exported\n'
        '${result['imagesFailed']} images failed\n\n'
        'Location: ${result['folderPath']}',
      );
    } else {
      // Handle specific error types
      String error = result['error'] ?? 'unknown';
      String message = result['message'] ?? 'An error occurred';

      if (error == 'permission_denied') {
        // Permission was denied - show dialog to open settings
        _showPermissionDeniedDialog(context);
      } else if (error == 'cancelled') {
        // User cancelled - just show a brief message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export cancelled'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Other errors
        _showErrorDialog(context, 'Export Failed', message);
      }
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading dialog
    
    _showErrorDialog(
      context,
      'Export Error',
      'An unexpected error occurred: $e',
    );
  }
}

/// Show success dialog
void _showSuccessDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 32),
          SizedBox(width: 12),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('OK'),
        ),
      ],
    ),
  );
}

/// Show error dialog
void _showErrorDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error, color: Colors.red, size: 32),
          SizedBox(width: 12),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('OK'),
        ),
      ],
    ),
  );
}

/// Show permission denied dialog with option to open settings
void _showPermissionDeniedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 32),
          SizedBox(width: 12),
          Text('Permission Required'),
        ],
      ),
      content: Text(
        'Storage permission is required to export files.\n\n'
        'Please grant "All files access" or "Storage" permission in app settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.of(ctx).pop();
            // Open app settings
            await openAppSettings();
          },
          icon: Icon(Icons.settings),
          label: Text('Open Settings'),
        ),
      ],
    ),
  );
}
  
  /// Start export process
  void _exportMenuWithImages() async {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    
    if (menuProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No items to export. Please add items first.'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Count items with images
    final itemsWithImages = menuProvider.items.where((item) => item.imageUrl.isNotEmpty).length;
    
    // Show export preview dialog
    _showExportPreviewDialog(itemsWithImages);
  }

  /// Show export preview dialog
  void _showExportPreviewDialog(int itemsWithImages) {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Export Menu Items'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export Statistics:'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              _buildStatRow('Total Items:'.tr(), '${menuProvider.items.length}'),
              _buildStatRow('Categories:'.tr(), '${menuProvider.categories.length}'),
              _buildStatRow('Items with Images:'.tr(), '$itemsWithImages'),
              _buildStatRow(
                'Available:'.tr(), 
                '${menuProvider.items.where((item) => item.isAvailable).length}'
              ),
              
              const SizedBox(height: 16),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'What will be exported:'.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '📄 menu_items.xlsx - Excel file with all menu items'.tr(),
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                    Text(
                      '📁 images/ - Folder with all item images'.tr(),
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                    Text(
                      '📋 README sheet - Import instructions'.tr(),
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                    Text(
                      '📊 Summary sheet - Statistics'.tr(),
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performExport();
            },
            icon: const Icon(Icons.folder),
            label: Text('Export'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  /// Perform the export
  void _performExport() async {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Exporting menu items ...".tr()),
            SizedBox(height: 8),
            Text(
              'This may take a moment for large menus',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await ExcelImportService.exportMenuItemsWithImages(menuProvider.items);
      
      if (!mounted) return;
      Navigator.of(context).pop();

      if (result != null && result['success'] == true) {
        _showExportSuccessDialog(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export cancelled'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting: ${e.toString()}'.tr()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Show export success dialog
  void _showExportSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text('Export Successful!'.tr())),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export Summary:'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              _buildResultRow('Items Exported:'.tr(), '${result['itemsExported'.tr()]}'),
              _buildResultRow('Images Exported:'.tr(), '${result['imagesExported'.tr()]}', Colors.green),
              if (result['imagesFailed'] > 0)
                _buildResultRow('Images Failed:'.tr(), '${result['imagesFailed'.tr()]}', Colors.orange),

              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Location:'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      result['folderPath'],
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.folder_open, color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Folder Contents:'.tr(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('📄 menu_items.xlsx'.tr(), style: TextStyle(fontSize: 12)),
                    Text('📁 images/ (${result['imagesExported'.tr()]} files)', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(
                      'Keep these files together for reimport'.tr(),
                      style: TextStyle(fontSize: 11, color: Colors.green[700], fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'.tr()),
          ),
        ],
      ),
    );
  }



  /// Show confirmation dialog for deleting ALL items
  void _showDeleteAllConfirmationDialog() {
    final passwordController = TextEditingController();
    bool isPasswordVisible = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Text('Delete All Items?'.tr(), style: TextStyle(color: Colors.red)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This action will permanently delete ALL menu items and categories.\nThis cannot be undone.'.tr(),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Enter the password to confirm:'.tr()),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password'.tr(),
                    border: OutlineInputBorder(),
                    errorText: errorMessage,
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel'.tr()),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final enteredPassword = passwordController.text;
                  final correctPassword = dotenv.env['MENU_DELETE_PASSWORD'];

                  if (enteredPassword == correctPassword) {
                    Navigator.of(ctx).pop(); // Close password dialog
                    
                    // Proceed with deletion logic
                     _performDeleteAll();

                  } else {
                    setState(() {
                      errorMessage = 'Incorrect password'.tr();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                icon: Icon(Icons.delete_forever),
                label: Text('Delete All'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Future<void> _performDeleteAll() async {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final success = await Provider.of<MenuProvider>(context, listen: false).deleteAllMenuItems();
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All menu items deleted successfully'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete all items'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
  }

  // Show import dialog with category selection
  void _showImportDialog() {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    String? selectedImportCategory = menuProvider.categories.isNotEmpty 
        ? menuProvider.categories.first 
        : null;
    bool useExcelCategory = true; // Default to using Excel categories

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Import from Excel'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose category handling:'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                // Option 1: Use category from Excel
                RadioListTile<bool>(
                  title: Text('Use category from Excel file'.tr()),
                  subtitle: Text('Each item will use its own category from the file'.tr()),
                  value: true,
                  groupValue: useExcelCategory,
                  onChanged: (value) {
                    setState(() {
                      useExcelCategory = value ?? false;
                    });
                  },
                ),
                
                // Option 2: Assign all to one category
                RadioListTile<bool>(
                  title: Text('Assign all items to one category'.tr()),
                  subtitle: Text('All imported items will use the selected category'.tr()),
                  value: false,
                  groupValue: useExcelCategory,
                  onChanged: (value) {
                    setState(() {
                      useExcelCategory = value ?? false;
                    });
                  },
                ),
                
                // Category dropdown
                if (!useExcelCategory) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Select Category'.tr(),
                      border: OutlineInputBorder(),
                    ),
                    value: selectedImportCategory,
                    items: menuProvider.categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedImportCategory = value;
                      });
                    },
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Download template button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _downloadTemplate();
                  },
                  icon: const Icon(Icons.download),
                  label: Text('Download Template'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Format information
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Excel Format:'.tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Columns: Name | Price | Category | Available | Image File',
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                      Text(
                        '• Available values: Yes/No or True/False',
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                      Text(
                        '• images/ folder must be in same location as Excel file. So the images loaded automatically',
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                      Text(
                        '• Image files must match names in "Image File" column',
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'.tr()),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _importFromExcel(
                  useExcelCategory ? null : selectedImportCategory,
                  useExcelCategory,
                );
              },
              icon: const Icon(Icons.upload_file),
              label: Text('Select File'.tr()),
            ),
          ],
        ),
      ),
    );
  }


  /// Import from Excel with images
  void _importFromExcel(String? defaultCategory, bool useExcelCategory) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Reading Excel file...".tr())),
          ],
        ),
      ),
    );

    try {
      final items = await ExcelImportService.importMenuItemsFromExcelWithImages(
        useExcelCategory ? null : defaultCategory,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (items == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import cancelled or file not selected'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No valid items found in Excel file'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _showImportConfirmationDialog(items);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing: ${e.toString()}'.tr()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }


  /// Show import confirmation
  void _showImportConfirmationDialog(List<MenuItem> items) {
    Map<String, int> categoryCounts = {};
    int itemsWithImages = 0;
    
    for (var item in items) {
      categoryCounts[item.category] = (categoryCounts[item.category] ?? 0) + 1;
      if (item.imageUrl.isNotEmpty) itemsWithImages++;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Import'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${'Found'.tr()} ${items.length} ${'items to import:'.tr()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              ...categoryCounts.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${entry.key}:'),
                    Text(
                      '${entry.value} ${'items'.tr()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.image, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$itemsWithImages ${'items with images'.tr()}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will add all items to menu. Existing items not affected.'.tr(),
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performImport(items);
            },
            child: Text('Import'.tr()),
          ),
        ],
      ),
    );
  }

    /// Perform import
  void _performImport(List<MenuItem> items) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Importing items...".tr()),
            SizedBox(height: 8),
            Text(
              '0 / ${items.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );

    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    int successCount = 0;
    int failCount = 0;
    List<String> newCategories = [];

    for (int i = 0; i < items.length; i++) {
      try {
        final item = items[i];
        
        if (!menuProvider.categories.contains(item.category)) {
          await menuProvider.addCategory(item.category);
          if (!newCategories.contains(item.category)) {
            newCategories.add(item.category);
          }
        }
        
        await menuProvider.addMenuItem(item);
        successCount++;
      } catch (e) {
        debugPrint('Error importing item ${i + 1}: $e');
        failCount++;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    await menuProvider.fetchCategories(forceRefresh: true);
    await menuProvider.fetchMenu(forceRefresh: true);

    String message = failCount == 0
        ? 'Successfully imported $successCount items!'.tr()
        : 'Imported $successCount items. $failCount failed.'.tr();

    if (newCategories.isNotEmpty) {
      message += '\n${'New categories:'.tr()} ${newCategories.join(', ')}';
    }
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );

    _resetForm();
  }

  /// Download template
  void _downloadTemplate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Creating template...".tr())),
          ],
        ),
      ),
    );

    try {
      final filePath = await ExcelImportService.createSampleTemplate();
      
      if (!mounted) return;
      Navigator.of(context).pop();

      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template saved successfully!'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template download cancelled'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating template: ${e.toString()}'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
  // Show edit category dialog
  void _showEditCategoryDialog(String currentCategory) {
    final controller = TextEditingController(text: currentCategory);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Category'.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Category Name'.tr(),
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text('Save'.tr()),
            onPressed: () {
              final newCategory = controller.text.trim();
              if (newCategory.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category name cannot be empty'.tr()),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.of(ctx).pop();
              _updateCategory(currentCategory, newCategory);
            },
          ),
        ],
      ),
    );
  }

  // Update category
  void _updateCategory(String oldCategory, String newCategory) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Updating category...".tr())
          ],
        ),
      ),
    );
    
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    final success = await menuProvider.updateCategory(oldCategory, newCategory);
    
    if (!mounted) return;
    
    // Close loading dialog
    Navigator.of(context).pop();
    
    // Show result message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success 
            ? 'Category updated successfully'.tr() 
            : 'Failed to update category. Name may already exist.'.tr()
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    
    if (success) {
      // Update selected category to the new name
      setState(() {
        _selectedCategory = newCategory;
      });
      
      // Refresh data
      await menuProvider.fetchCategories(forceRefresh: true);
      await menuProvider.fetchMenu(forceRefresh: true);
    }
  }

  // Show delete category confirmation
  void _showDeleteCategoryConfirmation(String category) async {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    final itemCount = menuProvider.getCategoryItemCount(category);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Category'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${'Are you sure you want to delete category'.tr()} "$category"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${'This will delete'.tr()} $itemCount ${'items in this category'.tr()}.',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: Text('Delete'.tr(), style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      _deleteCategory(category);
    }
  }

  // Delete category
  void _deleteCategory(String category) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Deleting category...".tr())
          ],
        ),
      ),
    );
    
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    final success = await menuProvider.deleteCategory(category);
    
    if (!mounted) return;
    
    // Close loading dialog
    Navigator.of(context).pop();
    
    // Show result message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success 
            ? 'Category deleted successfully'.tr() 
            : 'Failed to delete category. Please try again.'.tr()
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    
    if (success) {
      // Reset selected category
      setState(() {
        if (menuProvider.categories.isNotEmpty) {
          _selectedCategory = menuProvider.categories.first;
        } else {
          _selectedCategory = '';
        }
      });
      
      // Refresh data
      await menuProvider.fetchCategories(forceRefresh: true);
      await menuProvider.fetchMenu(forceRefresh: true);
    }
  }
  void _resetForm() {
    _nameController.clear();
    _priceController.clear();
    _categoryController.clear();
    setState(() {
      _isAvailable = true;
      _isTaxExempt = false;
      _isPerPlate = false; // NEW
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
      _isTaxExempt = item.taxExempt; 
      _isPerPlate = item.isPerPlate; // NEW
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
        imageQuality: 85, // Higher quality
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
             SnackBar(content: Text('Could not access the selected image'.tr())),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image'.tr())),
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
    bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    
    if (isDesktop) {
      // Use camera package for desktop
      final File? capturedImage = await CameraHelper.capturePhoto(context);
      
      if (!mounted) return;
      
      if (capturedImage != null && await capturedImage.exists()) {
        setState(() {
          _selectedImage = capturedImage;
          _base64Image = null;
        });
      }
    } else {
      // Use image_picker for mobile (existing code)
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 300,
        maxHeight: 300,
      );
      
      if (!mounted) return;
      
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        
        if (await imageFile.exists()) {
          if (!mounted) return;
          setState(() {
            _selectedImage = imageFile;
            _base64Image = null;
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not access the captured photo'.tr())),
          );
        }
      }
    }
  } catch (e) {
    debugPrint('Error taking photo: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error taking photo: ${e.toString()}'.tr())),
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
        title:  Text('Delete Item'.tr()),
        content: Text('${'Are you sure you want to delete'.tr()} "${item.name}"?'),        actions: [
          TextButton(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child:  Text('Delete'.tr(), style: TextStyle(color: Colors.red)),
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
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Deleting item...".tr())
          ],
        ),
      ),
    );
    
    bool success = false;
    String errorMessage = 'Failed to delete item. Please try again.'.tr();
    
    try {
      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      success = await menuProvider.deleteMenuItem(item.id);
      
      // Refresh menu and categories on success
      if (success) {
        await menuProvider.fetchMenu();
        await menuProvider.fetchCategories();
      }
    } catch (e) {
      success = false;
      // If the error contains "foreign key constraint", provide a clearer message
      if (e.toString().toLowerCase().contains('foreign key') || 
          e.toString().toLowerCase().contains('constraint')) {
        errorMessage = 'This item cannot be deleted because it is used in existing orders.'.tr();
      } else {
        errorMessage = 'Error'.tr();
      }
      debugPrint('Exception during delete: $e');
    }
    
    if (!mounted) return;
    
    // Close the loading dialog
    Navigator.of(context).pop();
    
    // Show result message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Item deleted successfully'.tr() : errorMessage),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
        action: success ? null : SnackBarAction(
          label: 'Dismiss'.tr(),
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

      // ADD THIS DEBUG LOG RIGHT HERE
      debugPrint('=== SAVING ITEM ===');
      debugPrint('Current _isTaxExempt state: $_isTaxExempt');
      debugPrint('Is editing: ${_editingItem != null}');

    // Validate category
    if (_selectedCategory.isEmpty && !_isAddingNewCategory) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a category'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // IMPORTANT: Capture the state values BEFORE any async operations
    final bool capturedTaxExempt = _isTaxExempt;
    final bool capturedIsAvailable = _isAvailable;
    final bool capturedIsPerPlate = _isPerPlate; // NEW
    final String capturedName = _nameController.text.trim();
    final double capturedPrice = double.parse(_priceController.text);

    // Add debug log to verify
    debugPrint('💾 Saving item - taxExempt: $capturedTaxExempt, isAvailable: $capturedIsAvailable');
  
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    
    // Show saving dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>  AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Saving item...".tr())
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
          throw Exception("Failed to add category".tr());
        }
        await menuProvider.fetchCategories();
        _selectedCategory = categoryToUse;
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add category'.tr()),
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
           SnackBar(
            content: Text('Failed to process image. Please try a different one.'.tr()),
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

    // Create the item with proper data
    final item = MenuItem(
      id: _editingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: capturedName,           // ← Use captured value
      price: capturedPrice,          // ← Use captured value
      category: categoryToUse,
      imageUrl: imageUrl,
      isAvailable: capturedIsAvailable,  // ← Use captured value

      taxExempt: capturedTaxExempt,
      isPerPlate: capturedIsPerPlate, // NEW
    );
     // Debug log to verify the item being saved
     debugPrint('💾 MenuItem created - taxExempt: ${item.taxExempt}');
    // Save to database
    bool success = false;
    String errorMessage = ''; // Capture the specific error

    try {
      if (_editingItem == null) {
        await menuProvider.addMenuItem(item);
      } else {
        await menuProvider.updateMenuItem(item);
      }
      success = true;
    } catch (e) {
      success = false;
      errorMessage = e.toString(); // Store the actual error
      debugPrint('Error saving item: $errorMessage');
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // Close dialog

    // Show result message
    final message = _editingItem == null ? 'Item added successfully'.tr() : 'Item updated successfully'.tr();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // Show specific error if failed
        content: Text(success ? message : 'Failed: $errorMessage'), 
        backgroundColor: success ? Colors.green : Colors.red,
        duration: Duration(seconds: success ? 2 : 10), // Longer duration for error reading
        action: success ? null : SnackBarAction(
          label: 'Copy',
          textColor: Colors.white,
          onPressed: () {
             // Optional: Allow copying to clipboard if we had the service, 
             // for now just allow dismissing or maybe retry
             ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
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
          return _buildErrorImagePreview('Image file not found'.tr());
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
        return _buildErrorImagePreview('Error showing image'.tr());
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
            return _buildErrorImagePreview('Image file not found'.tr());
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
          return _buildErrorImagePreview('Invalid file path'.tr());
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
            return _buildErrorImagePreview('Failed to load image'.tr());
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
            'No image selected'.tr(),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Extract items list panel
  Widget _buildItemsList() {
    final menuProvider = Provider.of<MenuProvider>(context);
    
    List<MenuItem> displayedItems = [];
    if (_selectedCategory.isNotEmpty && menuProvider.categories.contains(_selectedCategory)) {
      displayedItems = menuProvider.getItemsByCategory(_selectedCategory);
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category dropdown for the list panel
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Category'.tr(),
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
                    hint: Text('Select a category'.tr()),
                  ),
                ),
                const SizedBox(width: 8),
                // Edit category button
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: _selectedCategory.isEmpty || !menuProvider.categories.contains(_selectedCategory)
                      ? null
                      : () => _showEditCategoryDialog(_selectedCategory),
                  tooltip: 'Edit category'.tr(),
                ),
                // Delete category button
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _selectedCategory.isEmpty || !menuProvider.categories.contains(_selectedCategory)
                      ? null
                      : () => _showDeleteCategoryConfirmation(_selectedCategory),
                  tooltip: 'Delete category'.tr(),
                ),
              ],
            ),
          ),

          // Items list
          Expanded(
            child: _selectedCategory.isEmpty || !menuProvider.categories.contains(_selectedCategory) ? 
               Center(child: Text('No category selected'.tr())) :
               displayedItems.isEmpty ?
              Center(child: Text('No items in this category'.tr())) :
              ListView.builder(
                key: _listKey,
                itemCount: displayedItems.length,
                itemBuilder: (ctx, index) {
                  final item = displayedItems[index];
                  
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
                          item.isAvailable ? 'Available'.tr() : 'Out of stock'.tr(),
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
    );
  }

  // Extract form panel
  Widget _buildForm() {
    final menuProvider = Provider.of<MenuProvider>(context);
    
    return Card(
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
                  _editingItem == null ? 'Add New Item'.tr() : 'Edit Item'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Name field
                DoubleTapKeyboardListener(
                  focusNode: _nameFocus,
                  child: TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    decoration: InputDecoration(
                      labelText: 'Name'.tr(),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name'.tr();
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Price field
                DoubleTapKeyboardListener(
                  focusNode: _priceFocus,
                  child: TextFormField(
                    controller: _priceController,
                    focusNode: _priceFocus,
                    decoration:  InputDecoration(
                      labelText: 'Price'.tr(),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a price'.tr();
                      }
                      try {
                        double.parse(value);
                      } catch (e) {
                        return 'Please enter a valid number'.tr();
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Category field - either dropdown or text input based on state
                _isAddingNewCategory
                  ? Row(
                      children: [
                        Expanded(
                          child: DoubleTapKeyboardListener(
                            focusNode: _categoryFocus,
                            child: TextFormField(
                              controller: _categoryController,
                              focusNode: _categoryFocus,
                              decoration:  InputDecoration(
                                labelText: 'New Category'.tr(),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a category name'.tr();
                                }
                                return null;
                              },
                            ),
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
                            decoration:  InputDecoration(
                              labelText: 'Category'.tr(),
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
                                return 'Please select a category'.tr();
                              }
                              return null;
                            },
                            hint: Text('Select a category'.tr()),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _toggleCategoryInput(true),
                          tooltip: 'Add new category'.tr(),
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
                     Text(
                      'Item Image (Optional)'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                     if (_selectedImage != null || _base64Image != null)
                        TextButton.icon(
                          icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                          label: Text('Remove Image'.tr(), style: TextStyle(color: Colors.red)),
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
                          label:  Text('Gallery'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label:  Text('Camera'.tr()),
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
                                'No image selected'.tr(),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '(Images are optional)'.tr(),
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
                    Text('Available'.tr()),
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
                const SizedBox(height: 8), // NEW: Add spacing

                // NEW: Tax Exempt switch
                Row(
                  children: [
                    Text('Tax Exempt'.tr()),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Enable this to exclude tax for this item'.tr(),
                      child: Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    ),
                    Switch(
                      value: _isTaxExempt,
                      onChanged: (value) {
                        setState(() {
                          _isTaxExempt = value;
                          debugPrint('Tax Exempt checkbox changed to: $_isTaxExempt'); // ADD THIS LINE
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // NEW: Per Plate Pricing switch
                if (widget.allowPerPlatePricing)
                  Row(
                    children: [
                      Text('Per Plate Pricing'.tr()),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Price is per person based on event guest count'.tr(),
                        child: Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      ),
                      Switch(
                        value: _isPerPlate,
                        onChanged: (value) {
                          setState(() {
                            _isPerPlate = value;
                          });
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 32), // Add extra space at bottom

                // Form buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: Import and Export buttons
                    Row(
                      children: [
                        // Import from Excel button
                        ElevatedButton.icon(
                          onPressed: _showImportDialog,
                          icon: const Icon(Icons.file_upload, size: 20),
                          label: Text('Import Menu'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Export to Excel button
                        ElevatedButton.icon(
                          onPressed: _exportMenuWithImages,
                          icon: const Icon(Icons.file_download, size: 20),
                          label: Text('Export Menu'.tr()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    
                    // Spacer to push Cancel and Add/Update to the right
                    const Spacer(),
                    
                    // Right side: Cancel and Add/Update buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _resetForm,
                          child: Text('Cancel'.tr()),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveItemToDatabase,
                          child: Text(_editingItem == null ? 'Add Item'.tr() : 'Update Item'.tr()),
                        ),
                      ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = Provider.of<MenuProvider>(context);
    
    if (_selectedCategory.isEmpty && menuProvider.categories.isNotEmpty) {
      _selectedCategory = menuProvider.categories.first;
    }

    return Scaffold(
      appBar: AppBar(
        title:  Text('Products'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: 'Delete All Items'.tr(),
            onPressed: _showDeleteAllConfirmationDialog,
          ),
        ],
      ),
      // Make the body responsive with LayoutBuilder
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth >= 900;
            
            if (isWideScreen) {
              // Wide screen: Row layout (left list + right form)
              return Row(
                children: [
                  // Menu items list (left side)
                  Expanded(
                    flex: 2,
                    child: _buildItemsList(),
                  ),
                  // Form for adding/editing (right side)
                  Expanded(
                    flex: 3,
                    child: _buildForm(),
                  ),
                ],
              );
            } else {
              // Narrow screen: Column layout (list on top, form below)
              return Column(
                children: [
                  // Menu items list (top)
                  Expanded(
                    flex: 2,
                    child: _buildItemsList(),
                  ),
                  // Form for adding/editing (bottom)
                  Expanded(
                    flex: 3,
                    child: _buildForm(),
                  ),
                ],
              );
            }
          },
        ),
      ),
      // Add resizeToAvoidBottomInset to make sure the keyboard doesn't overlap content
      resizeToAvoidBottomInset: true,
    );
  }
}
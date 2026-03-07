import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../models/menu_item.dart';

class ExcelImportService {
  /// Request storage permissions before export
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+)
      if (await Permission.manageExternalStorage.isGranted) {
        debugPrint('✅ MANAGE_EXTERNAL_STORAGE already granted');
        return true;
      }

      // Try to request MANAGE_EXTERNAL_STORAGE (All Files Access)
      var status = await Permission.manageExternalStorage.request();
      
      if (status.isGranted) {
        debugPrint('✅ MANAGE_EXTERNAL_STORAGE granted');
        return true;
      }

      // If MANAGE_EXTERNAL_STORAGE not granted, try regular storage permission
      if (await Permission.storage.isGranted) {
        debugPrint('✅ Storage permission already granted');
        return true;
      }

      status = await Permission.storage.request();
      
      if (status.isGranted) {
        debugPrint('✅ Storage permission granted');
        return true;
      }

      if (status.isPermanentlyDenied) {
        debugPrint('❌ Storage permission permanently denied');
        return false;
      }

      debugPrint('⚠️ Storage permission denied');
      return false;
    }
    
    // For iOS and other platforms, assume granted
    return true;
  }

  /// Export menu items with images to folder structure
  /// Now includes runtime permission checks
  static Future<Map<String, dynamic>?> exportMenuItemsWithImages(List<MenuItem> items) async {
    try {
      if (items.isEmpty) {
        debugPrint('No items to export');
        return null;
      }

      // ⭐ REQUEST PERMISSIONS FIRST
      debugPrint('📋 Checking storage permissions...');
      bool hasPermission = await _requestStoragePermission();
      
      if (!hasPermission) {
        debugPrint('❌ Storage permission not granted');
        return {
          'success': false,
          'error': 'permission_denied',
          'message': 'Storage permission is required to export files. Please grant permission in app settings.',
        };
      }

      debugPrint('✅ Storage permissions granted, proceeding with export...');

      // Ask user to select folder for export
      String? folderPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Folder',
      );

      if (folderPath == null) {
        debugPrint('Export cancelled by user');
        return {
          'success': false,
          'error': 'cancelled',
          'message': 'Export cancelled',
        };
      }

      debugPrint('📁 Selected folder: $folderPath');

      // Create timestamped export folder
      final timestamp = DateTime.now();
      final dateStr = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}';
      final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';
      
      final exportFolderName = 'menu_export_${dateStr}_$timeStr';
      final exportFolder = Directory(path.join(folderPath, exportFolderName));
      final imagesFolder = Directory(path.join(exportFolder.path, 'images'));
      
      // Create folders
      debugPrint('📁 Creating export directories...');
      await exportFolder.create(recursive: true);
      await imagesFolder.create(recursive: true);

      debugPrint('📁 Export folder: ${exportFolder.path}');
      debugPrint('📁 Images folder: ${imagesFolder.path}');

      // Track exported images
      Map<String, String> imageExports = {}; // item.id -> image filename
      int imagesExported = 0;
      int imagesFailed = 0;

      // Export images first
      debugPrint('🖼️ Starting image export...');
      for (var item in items) {
        if (item.imageUrl.isNotEmpty) {
          try {
            String? imageFileName = await _exportImage(item, imagesFolder.path);
            if (imageFileName != null) {
              imageExports[item.id] = imageFileName;
              imagesExported++;
              debugPrint('✅ Exported image: $imageFileName');
            } else {
              imagesFailed++;
              debugPrint('⚠️ Failed to export image for: ${item.name}');
            }
          } catch (e) {
            debugPrint('❌ Error exporting image for ${item.name}: $e');
            imagesFailed++;
          }
        }
      }

      debugPrint('📊 Images: $imagesExported exported, $imagesFailed failed');

      // Create Excel workbook
      debugPrint('📝 Creating Excel file...');
      var excel = Excel.createExcel();
      String sheetName = 'Menu Items';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
      Sheet sheet = excel[sheetName];

      // Define styles
      CellStyle headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.white,
      );

      CellStyle evenRowStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#F2F2F2'),
      );

      // Add headers
      final headers = ['Name', 'Price', 'Cost', 'Category', 'Available', 'Barcode', 'Image File'];
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Group items by category
      Map<String, List<MenuItem>> itemsByCategory = {};
      for (var item in items) {
        if (!itemsByCategory.containsKey(item.category)) {
          itemsByCategory[item.category] = [];
        }
        itemsByCategory[item.category]!.add(item);
      }
      
      var sortedCategories = itemsByCategory.keys.toList()..sort();

      // Add data rows
      int rowIndex = 1;
      for (var category in sortedCategories) {
        final categoryItems = itemsByCategory[category]!;
        categoryItems.sort((a, b) => a.name.compareTo(b.name));
        
        for (var item in categoryItems) {
          CellStyle? rowStyle = rowIndex % 2 == 0 ? evenRowStyle : null;

          // Name
          var nameCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
          nameCell.value = TextCellValue(item.name);
          if (rowStyle != null) nameCell.cellStyle = rowStyle;

          // Price
          var priceCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
          priceCell.value = DoubleCellValue(item.price);
          if (rowStyle != null) priceCell.cellStyle = rowStyle;

          // Cost
          var costCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
          costCell.value = DoubleCellValue(item.purchasePrice);
          if (rowStyle != null) costCell.cellStyle = rowStyle;

          // Category
          var categoryCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
          categoryCell.value = TextCellValue(item.category);
          if (rowStyle != null) categoryCell.cellStyle = rowStyle;

          // Available
          var availableCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
          availableCell.value = TextCellValue(item.isAvailable ? 'Yes' : 'No');
          if (rowStyle != null) availableCell.cellStyle = rowStyle;

          // Barcode
          var barcodeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex));
          barcodeCell.value = TextCellValue(item.barcode);
          if (rowStyle != null) barcodeCell.cellStyle = rowStyle;

          // Image File Reference
          var imageCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex));
          if (imageExports.containsKey(item.id)) {
            imageCell.value = TextCellValue('images/${imageExports[item.id]}');
          } else {
            imageCell.value = TextCellValue('');
          }
          if (rowStyle != null) imageCell.cellStyle = rowStyle;

          rowIndex++;
        }
      }

      // Add summary sheet
      _addSummarySheet(excel, items, itemsByCategory);

      // Add README sheet
      _addReadmeSheet(excel, imagesExported, imagesFailed);

      // Save Excel file
      debugPrint('💾 Saving Excel file...');
      var fileBytes = excel.save();
      if (fileBytes == null) {
        debugPrint('❌ Error: Failed to generate Excel file');
        return {
          'success': false,
          'error': 'excel_generation_failed',
          'message': 'Failed to generate Excel file',
        };
      }

      final excelPath = path.join(exportFolder.path, 'menu_items.xlsx');
      final excelFile = File(excelPath);
      await excelFile.writeAsBytes(fileBytes);

      debugPrint('✅ Excel file saved: $excelPath');
      debugPrint('🎉 Export completed successfully!');

      return {
        'success': true,
        'excelPath': excelPath,
        'folderPath': exportFolder.path,
        'itemsExported': items.length,
        'imagesExported': imagesExported,
        'imagesFailed': imagesFailed,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error exporting menu with images: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': 'export_failed',
        'message': 'Error exporting: $e',
      };
    }
  }

  /// Export individual image file
  /// FIXED: Now properly handles Arabic and other Unicode characters
  static Future<String?> _exportImage(MenuItem item, String imagesFolder) async {
    try {
      if (item.imageUrl.isEmpty) return null;

      // Generate safe filename - preserve Unicode characters (including Arabic)
      // Only remove filesystem-unsafe characters: < > : " / \ | ? *
      String safeItemName = item.name
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // Remove only filesystem-unsafe chars
          .replaceAll(' ', '_')
          .trim();
      
      // Limit length AFTER cleaning (important!)
      if (safeItemName.length > 30) {
        safeItemName = safeItemName.substring(0, 30);
      }
      
      // If name becomes empty after cleaning, use a fallback
      if (safeItemName.isEmpty) {
        safeItemName = 'item';
      }
      
      String fileName = '${item.id}_$safeItemName.jpg';
      String filePath = path.join(imagesFolder, fileName);

      debugPrint('🖼️ Exporting "${item.name}" to: $fileName');

      // Handle base64 images
      if (item.imageUrl.startsWith('data:image')) {
        final parts = item.imageUrl.split(',');
        if (parts.length != 2) {
          debugPrint('⚠️ Invalid base64 format for ${item.name}');
          return null;
        }

        String base64Content = parts[1].trim().replaceAll(RegExp(r'\s+'), '');

        // Add padding if needed
        int paddingNeeded = (4 - (base64Content.length % 4)) % 4;
        base64Content = base64Content.padRight(base64Content.length + paddingNeeded, '=');

        try {
          final imageData = base64Decode(base64Content);
          final file = File(filePath);
          
          // Ensure parent directory exists
          if (!await file.parent.exists()) {
            await file.parent.create(recursive: true);
          }
          
          await file.writeAsBytes(imageData);
          debugPrint('✅ Wrote ${imageData.length} bytes for ${item.name}');
          return fileName;
        } catch (e) {
          debugPrint('❌ Error writing image for ${item.name}: $e');
          return null;
        }
      }
      // Handle file:// URLs
      else if (item.imageUrl.startsWith('file://')) {
        final sourceFile = File(item.imageUrl.replaceFirst('file://', ''));
        if (await sourceFile.exists()) {
          await sourceFile.copy(filePath);
          debugPrint('✅ Copied file for ${item.name}');
          return fileName;
        } else {
          debugPrint('⚠️ Source file not found: ${item.imageUrl}');
        }
      }
      // Handle regular file paths
      else if (await File(item.imageUrl).exists()) {
        await File(item.imageUrl).copy(filePath);
        debugPrint('✅ Copied file for ${item.name}');
        return fileName;
      }

      debugPrint('⚠️ No valid image source for ${item.name}');
      return null;
    } catch (e) {
      debugPrint('❌ Error exporting image for ${item.name}: $e');
      return null;
    }
  }

  /// Add summary sheet to Excel workbook
  static void _addSummarySheet(Excel excel, List<MenuItem> items, Map<String, List<MenuItem>> itemsByCategory) {
    String summarySheetName = 'Summary';
    excel.copy(excel.getDefaultSheet() ?? 'Sheet1', summarySheetName);
    Sheet summarySheet = excel[summarySheetName];

    CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
      fontColorHex: ExcelColor.white,
    );

    // Title
    var titleCell = summarySheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('Menu Export Summary');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
    );

    // Statistics
    summarySheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Total Items:');
    summarySheet.cell(CellIndex.indexByString('B3')).value = IntCellValue(items.length);

    summarySheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('Total Categories:');
    summarySheet.cell(CellIndex.indexByString('B4')).value = IntCellValue(itemsByCategory.length);

    summarySheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('Export Date:');
    summarySheet.cell(CellIndex.indexByString('B5')).value = TextCellValue(DateTime.now().toString().split('.')[0]);

    // Category breakdown
    summarySheet.cell(CellIndex.indexByString('A7')).value = TextCellValue('Category');
    summarySheet.cell(CellIndex.indexByString('B7')).value = TextCellValue('Items');
    summarySheet.cell(CellIndex.indexByString('A7')).cellStyle = headerStyle;
    summarySheet.cell(CellIndex.indexByString('B7')).cellStyle = headerStyle;

    int row = 8;
    for (var category in itemsByCategory.keys.toList()..sort()) {
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row - 1))
          .value = TextCellValue(category);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row - 1))
          .value = IntCellValue(itemsByCategory[category]!.length);
      row++;
    }
  }

  /// Add README sheet to Excel workbook
  static void _addReadmeSheet(Excel excel, int imagesExported, int imagesFailed) {
    String readmeSheetName = 'README';
    excel.copy(excel.getDefaultSheet() ?? 'Sheet1', readmeSheetName);
    Sheet readmeSheet = excel[readmeSheetName];

    CellStyle titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
    );

    CellStyle sectionStyle = CellStyle(
      bold: true,
    );

    int row = 0;

    // Title
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('Menu Export Package - README');
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row - 1)).cellStyle = titleStyle;
    row++;

    // Export Info
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('Export Information:');
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row - 1)).cellStyle = sectionStyle;
    
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('• Images Exported: $imagesExported');
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('• Images Failed: $imagesFailed');
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('• Export Date: ${DateTime.now().toString().split('.')[0]}');
    row++;

    // File Structure
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('File Structure:');
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row - 1)).cellStyle = sectionStyle;
    
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('• menu_items.xlsx (or any .xlsx file) - Main menu data with image references');
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('• images/ - Folder containing all menu item images');
    row++;

    // Notes
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('Notes:');
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row - 1)).cellStyle = sectionStyle;
    
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('• Images with Arabic names are fully supported');
    readmeSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++))
        .value = TextCellValue('• Keep the folder structure intact for re-importing');
  }


  /// Import menu items from Excel file with images
  /// FIXED: Now handles the images folder correctly
  static Future<List<MenuItem>?> importMenuItemsFromExcelWithImages(String? category) async {
    try {
      // ⭐ OPTION 1: Let user select the FOLDER containing both Excel and images
      String? folderPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Folder Containing menu_items.xlsx and images/',
      );

      if (folderPath == null) {
        debugPrint('Import cancelled by user');
        return null;
      }

      debugPrint('📁 Selected folder: $folderPath');

      // Look for any .xlsx file in the selected folder
      final dir = Directory(folderPath);
      File? excelFile;
      
      try {
        final List<FileSystemEntity> entities = await dir.list().toList();
        final List<File> xlsxFiles = entities
            .whereType<File>()
            .where((file) => 
                file.path.toLowerCase().endsWith('.xlsx') && 
                !path.basename(file.path).startsWith('~\$')) // Ignore temp files
            .toList();

        if (xlsxFiles.isEmpty) {
          debugPrint('❌ Error: No .xlsx file found in selected folder');
          return null;
        }

        // prioritize 'menu_items.xlsx' if it exists, otherwise use the first one found
        try {
          excelFile = xlsxFiles.firstWhere(
            (file) => path.basename(file.path) == 'menu_items.xlsx'
          );
        } catch (_) {
          // If menu_items.xlsx not found, use the first available xlsx file
          excelFile = xlsxFiles.first;
        }
        
      } catch (e) {
        debugPrint('❌ Error scanning folder: $e');
        return null;
      }

      final excelFilePath = excelFile.path;
      debugPrint('📄 Found Excel file: $excelFilePath');

      // Read the Excel file
      final bytes = await excelFile.readAsBytes();
      var excel = Excel.decodeBytes(bytes);

      // Try to find the "Menu Items" sheet first
      Sheet? sheet = excel.tables['Menu Items'];
      
      // If not found, use the first available sheet
      if (sheet == null && excel.tables.isNotEmpty) {
        sheet = excel.tables.values.first;
        debugPrint('⚠️  "Menu Items" sheet not found, using first sheet: ${excel.tables.keys.first}');
      }

      if (sheet == null || sheet.rows.isEmpty) {
        debugPrint('❌ Error: No data found in Excel file');
        return null;
      }

      // Images folder is in the same directory as the Excel file
      final imagesFolder = path.join(folderPath, 'images');
      
      debugPrint('📁 Excel file: $excelFilePath');
      debugPrint('📁 Looking for images in: $imagesFolder');

      // Check if images folder exists
      final imagesFolderDir = Directory(imagesFolder);
      if (!await imagesFolderDir.exists()) {
        debugPrint('⚠️  Warning: images folder not found at $imagesFolder');
      } else {
        // List files in images folder for debugging
        final imageFiles = await imagesFolderDir.list().toList();
        debugPrint('📂 Found ${imageFiles.length} files in images folder');
      }

      return _parseExcelSheetWithImages(sheet, category, imagesFolder);
    } catch (e) {
      debugPrint('❌ Error importing Excel file with images: $e');
      return null;
    }
  }

  /// Alternative import method: Select Excel file and copy images from same directory
  static Future<List<MenuItem>?> importMenuItemsFromExcelWithImagesV2(String? category) async {
    try {
      // Let user select the Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        dialogTitle: 'Select menu_items.xlsx',
      );

      if (result == null || result.files.single.path == null) {
        debugPrint('Import cancelled by user');
        return null;
      }

      final selectedFilePath = result.files.single.path!;
      debugPrint('📄 Selected file: $selectedFilePath');

      // ⭐ KEY FIX: Get the ORIGINAL folder path, not the cache path
      // FilePicker copies to cache, but we need to get the original location
      // Unfortunately, FilePicker doesn't give us the original path easily
      // So we need to ask user to select the folder instead (use method above)
      
      // For now, check if this is a cached path
      if (selectedFilePath.contains('cache/file_picker')) {
        debugPrint('⚠️  WARNING: File was copied to cache. Images folder not accessible.');
        debugPrint('💡 TIP: Export creates a folder with both Excel and images. Import that folder instead.');
        
        // Try to read just the Excel without images
        final bytes = await File(selectedFilePath).readAsBytes();
        var excel = Excel.decodeBytes(bytes);
        
        Sheet? sheet = excel.tables['Menu Items'] ?? excel.tables.values.first;
        
        if (sheet.rows.isEmpty) {
          return null;
        }

        // Parse without images (since we can't access them)
        return _parseExcelSheetWithoutImages(sheet, category);
      }

      // If not cached, proceed normally
      final excelFolder = path.dirname(selectedFilePath);
      final imagesFolder = path.join(excelFolder, 'images');
      
      final bytes = await File(selectedFilePath).readAsBytes();
      var excel = Excel.decodeBytes(bytes);
      
      Sheet? sheet = excel.tables['Menu Items'] ?? excel.tables.values.first;
      
      if (sheet.rows.isEmpty) {
        return null;
      }

      debugPrint('📁 Looking for images in: $imagesFolder');
      
      return _parseExcelSheetWithImages(sheet, category, imagesFolder);
    } catch (e) {
      debugPrint('❌ Error importing Excel file: $e');
      return null;
    }
  }

  /// Parse Excel sheet WITH images
  static Future<List<MenuItem>> _parseExcelSheetWithImages(
    Sheet sheet, 
    String? defaultCategory, 
    String imagesFolder,
  ) async {
    List<MenuItem> items = [];
    int imagesLoaded = 0;
    int imagesMissing = 0;

    // Read headers to map columns dynamically
    Map<String, int> columnMap = {};
    if (sheet.rows.isNotEmpty) {
      final headerRow = sheet.rows[0];
      for (int i = 0; i < headerRow.length; i++) {
        final cellValue = _getCellValue(headerRow, i)?.trim().toLowerCase();
        if (cellValue != null) {
          columnMap[cellValue] = i;
        }
      }
    }

    // Default indices if headers not found (for backwards compatibility)
    int nameCol = columnMap['name'] ?? 0;
    int priceCol = columnMap['price'] ?? 1;
    int costCol = columnMap['cost'] ?? -1;
    int categoryCol = columnMap['category'] ?? 2;
    int availableCol = columnMap['available'] ?? 3;
    int barcodeCol = columnMap['barcode'] ?? -1;
    int imageCol = columnMap['image file'] ?? 4;
    
    // Skip header row (index 0)
    for (int i = 1; i < sheet.rows.length; i++) {
      try {
        final row = sheet.rows[i];
        
        if (row.isEmpty || _isRowEmpty(row)) continue;

        // Extract values using dynamic columns
        final name = _getCellValue(row, nameCol)?.trim();
        final priceStr = _getCellValue(row, priceCol);
        final costStr = costCol >= 0 ? _getCellValue(row, costCol) : null;
        final categoryFromExcel = _getCellValue(row, categoryCol)?.trim();
        final availableStr = _getCellValue(row, availableCol);
        final barcodeFromExcel = barcodeCol >= 0 ? _getCellValue(row, barcodeCol)?.trim() ?? '' : '';
        final imageFileName = _getCellValue(row, imageCol)?.trim() ?? '';

        // Validate required fields
        if (name == null || name.isEmpty || priceStr == null || priceStr.isEmpty) {
          debugPrint('Row $i: Skipping - missing name or price');
          continue;
        }

        // Parse price
        double? price;
        try {
          price = double.parse(priceStr.replaceAll(RegExp(r'[^\d.]'), ''));
        } catch (e) {
          debugPrint('Row $i: Skipping - invalid price');
          continue;
        }

        // Parse cost
        double purchasePrice = 0.0;
        if (costStr != null && costStr.isNotEmpty) {
          try {
            purchasePrice = double.parse(costStr.replaceAll(RegExp(r'[^\d.]'), ''));
          } catch (e) {
            debugPrint('Row $i: Invalid cost');
          }
        }

        // Determine category
        String itemCategory = defaultCategory ?? '';
        if (categoryFromExcel != null && categoryFromExcel.isNotEmpty) {
          itemCategory = categoryFromExcel;
        }

        if (itemCategory.isEmpty) {
          debugPrint('Row $i: Skipping - no category');
          continue;
        }

        // Parse availability
        bool isAvailable = true;
        if (availableStr != null && availableStr.isNotEmpty) {
          final availableLower = availableStr.toLowerCase();
          isAvailable = availableLower == 'yes' || 
                       availableLower == 'true' || 
                       availableLower == '1' ||
                       availableLower == 'available';
        }

        // Handle image file
        String imageUrl = '';
        if (imageFileName.isNotEmpty) {
          // Remove 'images/' prefix if present
          String cleanFileName = imageFileName
              .replaceAll('images/', '')
              .replaceAll('images\\', '');
          
          final imageFilePath = path.join(imagesFolder, cleanFileName);
          final imageFile = File(imageFilePath);
          
          debugPrint('🔍 Looking for image: $imageFilePath');
          
          if (await imageFile.exists()) {
            try {
              final imageBytes = await imageFile.readAsBytes();
              final base64String = base64Encode(imageBytes);
              imageUrl = 'data:image/jpeg;base64,$base64String';
              imagesLoaded++;
              debugPrint('✅ Loaded image: $cleanFileName (${imageBytes.length} bytes)');
            } catch (e) {
              debugPrint('❌ Error loading image $cleanFileName: $e');
              imagesMissing++;
            }
          } else {
            debugPrint('⚠️  Image not found: $imageFilePath');
            imagesMissing++;
          }
        }

        // Create MenuItem
        final item = MenuItem(
          id: 'import_${DateTime.now().millisecondsSinceEpoch}_$i',
          name: name,
          price: price,
          purchasePrice: purchasePrice,
          barcode: barcodeFromExcel,
          category: itemCategory,
          imageUrl: imageUrl,
          isAvailable: isAvailable,
        );

        items.add(item);
        debugPrint('✅ Parsed item: $name ${imageUrl.isNotEmpty ? "WITH image" : "WITHOUT image"}');
      } catch (e) {
        debugPrint('❌ Error parsing row $i: $e');
        continue;
      }
    }

    debugPrint('📊 Import complete: ${items.length} items, $imagesLoaded images loaded, $imagesMissing images missing');
    return items;
  }

  /// Parse Excel sheet WITHOUT images (fallback when images not accessible)
  static List<MenuItem> _parseExcelSheetWithoutImages(Sheet sheet, String? defaultCategory) {
    List<MenuItem> items = [];

    // Read headers to map columns dynamically
    Map<String, int> columnMap = {};
    if (sheet.rows.isNotEmpty) {
      final headerRow = sheet.rows[0];
      for (int i = 0; i < headerRow.length; i++) {
        final cellValue = _getCellValue(headerRow, i)?.trim().toLowerCase();
        if (cellValue != null) {
          columnMap[cellValue] = i;
        }
      }
    }

    // Default indices if headers not found
    int nameCol = columnMap['name'] ?? 0;
    int priceCol = columnMap['price'] ?? 1;
    int costCol = columnMap['cost'] ?? -1;
    int categoryCol = columnMap['category'] ?? 2;
    int availableCol = columnMap['available'] ?? 3;
    int barcodeCol = columnMap['barcode'] ?? -1;
    
    for (int i = 1; i < sheet.rows.length; i++) {
      try {
        final row = sheet.rows[i];
        
        if (row.isEmpty || _isRowEmpty(row)) continue;

        // Extract values
        final name = _getCellValue(row, nameCol)?.trim();
        final priceStr = _getCellValue(row, priceCol);
        final costStr = costCol >= 0 ? _getCellValue(row, costCol) : null;
        final categoryFromExcel = _getCellValue(row, categoryCol)?.trim();
        final availableStr = _getCellValue(row, availableCol);
        final barcodeFromExcel = barcodeCol >= 0 ? _getCellValue(row, barcodeCol)?.trim() ?? '' : '';

        if (name == null || name.isEmpty || priceStr == null || priceStr.isEmpty) {
          continue;
        }

        double? price;
        try {
          price = double.parse(priceStr.replaceAll(RegExp(r'[^\d.]'), ''));
        } catch (e) {
          continue;
        }

        // Parse cost
        double purchasePrice = 0.0;
        if (costStr != null && costStr.isNotEmpty) {
          try {
            purchasePrice = double.parse(costStr.replaceAll(RegExp(r'[^\d.]'), ''));
          } catch (e) {
            // keep default 0.0
          }
        }

        String itemCategory = defaultCategory ?? '';
        if (categoryFromExcel != null && categoryFromExcel.isNotEmpty) {
          itemCategory = categoryFromExcel;
        }

        if (itemCategory.isEmpty) continue;

        bool isAvailable = true;
        if (availableStr != null && availableStr.isNotEmpty) {
          final availableLower = availableStr.toLowerCase();
          isAvailable = availableLower == 'yes' || 
                       availableLower == 'true' || 
                       availableLower == '1' ||
                       availableLower == 'available';
        }

        final item = MenuItem(
          id: 'import_${DateTime.now().millisecondsSinceEpoch}_$i',
          name: name,
          price: price,
          purchasePrice: purchasePrice,
          barcode: barcodeFromExcel,
          category: itemCategory,
          imageUrl: '', // No image
          isAvailable: isAvailable,
        );

        items.add(item);
      } catch (e) {
        continue;
      }
    }

    debugPrint('📊 Import complete (without images): ${items.length} items');
    return items;
  }

  /// Get cell value as string
  static String? _getCellValue(List<Data?> row, int index) {
    if (index >= row.length) return null;
    
    final cell = row[index];
    if (cell == null || cell.value == null) return null;
    
    return cell.value.toString();
  }

  /// Check if row is empty
  static bool _isRowEmpty(List<Data?> row) {
    for (var cell in row) {
      if (cell != null && cell.value != null && cell.value.toString().trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Create sample template (simple version without images)
  static Future<String?> createSampleTemplate() async {
    try {
      var excel = Excel.createExcel();
      String sheetName = 'Menu Items';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
      Sheet sheet = excel[sheetName];

      CellStyle headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.white,
      );

      // Add headers
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Name');
      sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Price');
      sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Category');
      sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Available');
      sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Image File');

      for (var col in ['A', 'B', 'C', 'D', 'E']) {
        sheet.cell(CellIndex.indexByString('${col}1')).cellStyle = headerStyle;
      }

      // Sample data
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Cappuccino');
      sheet.cell(CellIndex.indexByString('B2')).value = const DoubleCellValue(3.50);
      sheet.cell(CellIndex.indexByString('C2')).value = TextCellValue('Coffee');
      sheet.cell(CellIndex.indexByString('D2')).value = TextCellValue('Yes');
      sheet.cell(CellIndex.indexByString('E2')).value = TextCellValue('');

      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Espresso');
      sheet.cell(CellIndex.indexByString('B3')).value = const DoubleCellValue(2.50);
      sheet.cell(CellIndex.indexByString('C3')).value = TextCellValue('Coffee');
      sheet.cell(CellIndex.indexByString('D3')).value = TextCellValue('Yes');
      sheet.cell(CellIndex.indexByString('E3')).value = TextCellValue('');

      var fileBytes = excel.save();
      if (fileBytes == null) {
        debugPrint('Error: Failed to generate Excel file');
        return null;
      }

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Menu Template',
        fileName: 'menu_template.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile == null) {
        debugPrint('Save cancelled by user');
        return null;
      }

      final file = File(outputFile);
      await file.writeAsBytes(fileBytes);
      
      debugPrint('Template saved to: $outputFile');
      return outputFile;
    } catch (e) {
      debugPrint('Error creating sample template: $e');
      return null;
    }
  }
}
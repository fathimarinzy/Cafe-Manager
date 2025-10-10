import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/menu_item.dart';

class ExcelImportService {
  /// Export menu items with images to folder structure
  static Future<Map<String, dynamic>?> exportMenuItemsWithImages(List<MenuItem> items) async {
    try {
      if (items.isEmpty) {
        debugPrint('No items to export');
        return null;
      }

      // Ask user to select folder for export
      String? folderPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Export Folder',
      );

      if (folderPath == null) {
        debugPrint('Export cancelled by user');
        return null;
      }

      // Create timestamped export folder
      final timestamp = DateTime.now();
      final dateStr = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}';
      final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';
      
      final exportFolderName = 'menu_export_${dateStr}_$timeStr';
      final exportFolder = Directory(path.join(folderPath, exportFolderName));
      final imagesFolder = Directory(path.join(exportFolder.path, 'images'));
      
      // Create folders
      await exportFolder.create(recursive: true);
      await imagesFolder.create(recursive: true);

      debugPrint('📁 Export folder: ${exportFolder.path}');
      debugPrint('📁 Images folder: ${imagesFolder.path}');

      // Track exported images
      Map<String, String> imageExports = {}; // item.id -> image filename
      int imagesExported = 0;
      int imagesFailed = 0;

      // Export images first
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
      final headers = ['Name', 'Price', 'Category', 'Available', 'Image File'];
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

          // Category
          var categoryCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex));
          categoryCell.value = TextCellValue(item.category);
          if (rowStyle != null) categoryCell.cellStyle = rowStyle;

          // Available
          var availableCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex));
          availableCell.value = TextCellValue(item.isAvailable ? 'Yes' : 'No');
          if (rowStyle != null) availableCell.cellStyle = rowStyle;

          // Image File Reference
          var imageCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex));
          if (imageExports.containsKey(item.id)) {
            imageCell.value = TextCellValue('images/${imageExports[item.id]}');
          } else {
            imageCell.value = TextCellValue('');
          }
          if (rowStyle != null) imageCell.cellStyle = rowStyle;

          rowIndex++;
        }
      }

  // Column width setting is not supported by the excel package. These lines are removed.

      // Add summary sheet
      _addSummarySheet(excel, items, itemsByCategory);

      // Add README sheet
      _addReadmeSheet(excel, imagesExported, imagesFailed);

      // Save Excel file
      var fileBytes = excel.save();
      if (fileBytes == null) {
        debugPrint('❌ Error: Failed to generate Excel file');
        return null;
      }

      final excelPath = path.join(exportFolder.path, 'menu_items.xlsx');
      final excelFile = File(excelPath);
      await excelFile.writeAsBytes(fileBytes);

      debugPrint('✅ Excel file saved: $excelPath');

      return {
        'success': true,
        'excelPath': excelPath,
        'folderPath': exportFolder.path,
        'itemsExported': items.length,
        'imagesExported': imagesExported,
        'imagesFailed': imagesFailed,
      };
    } catch (e) {
      debugPrint('❌ Error exporting menu with images: $e');
      return null;
    }
  }

  /// Export individual image file
  static Future<String?> _exportImage(MenuItem item, String imagesFolder) async {
    try {
      if (item.imageUrl.isEmpty) return null;

      // Generate safe filename
      String safeItemName = item.name
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_')
          .substring(0, item.name.length > 30 ? 30 : item.name.length);
      
      String fileName = '${item.id}_$safeItemName.jpg';
      String filePath = path.join(imagesFolder, fileName);

      // Handle base64 images
      if (item.imageUrl.startsWith('data:image')) {
        final parts = item.imageUrl.split(',');
        if (parts.length != 2) return null;

        String base64Content = parts[1].trim().replaceAll(RegExp(r'\s+'), '');

        // Add padding if needed
        int paddingNeeded = (4 - (base64Content.length % 4)) % 4;
        base64Content = base64Content.padRight(base64Content.length + paddingNeeded, '=');

        try {
          final imageData = base64Decode(base64Content);
          final file = File(filePath);
          await file.writeAsBytes(imageData);
          return fileName;
        } catch (e) {
          debugPrint('Error decoding base64 for ${item.name}: $e');
          return null;
        }
      }
      // Handle file:// URLs
      else if (item.imageUrl.startsWith('file://')) {
        final sourceFile = File(item.imageUrl.replaceFirst('file://', ''));
        if (await sourceFile.exists()) {
          await sourceFile.copy(filePath);
          return fileName;
        }
      }
      // Handle absolute file paths
      else if (!item.imageUrl.startsWith('http')) {
        final sourceFile = File(item.imageUrl);
        if (await sourceFile.exists()) {
          await sourceFile.copy(filePath);
          return fileName;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error exporting image: $e');
      return null;
    }
  }

  /// Add summary sheet with statistics
  static void _addSummarySheet(Excel excel, List<MenuItem> items, Map<String, List<MenuItem>> itemsByCategory) {
    try {
      excel.copy('Menu Items', 'Summary');
      Sheet summarySheet = excel['Summary'];
  // summarySheet.clear(); // Not supported by excel package

      CellStyle headerStyle = CellStyle(
        bold: true,
        fontSize: 14,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.white,
      );

      CellStyle subHeaderStyle = CellStyle(
        bold: true,
        fontSize: 12,
        backgroundColorHex: ExcelColor.fromHexString('#8FAADC'),
      );

      // Title
      var titleCell = summarySheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('Menu Export Summary');
      titleCell.cellStyle = headerStyle;
      summarySheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

      // Export date
      summarySheet.cell(CellIndex.indexByString('A2')).value = 
        TextCellValue('Export Date: ${DateTime.now().toString().split('.')[0]}');
      summarySheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('D2'));

      // Statistics
      summarySheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('Total Items:');
      summarySheet.cell(CellIndex.indexByString('B4')).value = IntCellValue(items.length);

      int availableCount = items.where((item) => item.isAvailable).length;
      summarySheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('Available Items:');
      summarySheet.cell(CellIndex.indexByString('B5')).value = IntCellValue(availableCount);

      summarySheet.cell(CellIndex.indexByString('A6')).value = TextCellValue('Unavailable Items:');
      summarySheet.cell(CellIndex.indexByString('B6')).value = IntCellValue(items.length - availableCount);

      summarySheet.cell(CellIndex.indexByString('A7')).value = TextCellValue('Total Categories:');
      summarySheet.cell(CellIndex.indexByString('B7')).value = IntCellValue(itemsByCategory.length);

      int itemsWithImages = items.where((item) => item.imageUrl.isNotEmpty).length;
      summarySheet.cell(CellIndex.indexByString('A8')).value = TextCellValue('Items with Images:');
      summarySheet.cell(CellIndex.indexByString('B8')).value = IntCellValue(itemsWithImages);

      // Category breakdown
      summarySheet.cell(CellIndex.indexByString('A10')).value = TextCellValue('Category');
      summarySheet.cell(CellIndex.indexByString('A10')).cellStyle = subHeaderStyle;
      summarySheet.cell(CellIndex.indexByString('B10')).value = TextCellValue('Items');
      summarySheet.cell(CellIndex.indexByString('B10')).cellStyle = subHeaderStyle;
      summarySheet.cell(CellIndex.indexByString('C10')).value = TextCellValue('Avg Price');
      summarySheet.cell(CellIndex.indexByString('C10')).cellStyle = subHeaderStyle;
      summarySheet.cell(CellIndex.indexByString('D10')).value = TextCellValue('Total Value');
      summarySheet.cell(CellIndex.indexByString('D10')).cellStyle = subHeaderStyle;

      var sortedCategories = itemsByCategory.keys.toList()..sort();
      int row = 11;
      double grandTotal = 0;

      for (var category in sortedCategories) {
        final categoryItems = itemsByCategory[category]!;
        final itemCount = categoryItems.length;
        final avgPrice = categoryItems.map((e) => e.price).reduce((a, b) => a + b) / itemCount;
        final totalValue = categoryItems.map((e) => e.price).reduce((a, b) => a + b);
        grandTotal += totalValue;

        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(category);
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = IntCellValue(itemCount);
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = 
          DoubleCellValue(double.parse(avgPrice.toStringAsFixed(2)));
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = 
          DoubleCellValue(double.parse(totalValue.toStringAsFixed(2)));
        row++;
      }

      // Grand total
      row++;
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('TOTAL');
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = subHeaderStyle;
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = 
        DoubleCellValue(double.parse(grandTotal.toStringAsFixed(2)));
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = subHeaderStyle;

      // Price range
      if (items.isNotEmpty) {
        double minPrice = items.map((e) => e.price).reduce((a, b) => a < b ? a : b);
        double maxPrice = items.map((e) => e.price).reduce((a, b) => a > b ? a : b);

        row += 2;
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
          TextCellValue('Price Range:');
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = 
          TextCellValue('${minPrice.toStringAsFixed(2)} - ${maxPrice.toStringAsFixed(2)}');
      }

  // Column width setting is not supported by the excel package. These lines are removed.
    } catch (e) {
      debugPrint('Error creating summary sheet: $e');
    }
  }

  /// Add README sheet with instructions
  static void _addReadmeSheet(Excel excel, int imagesExported, int imagesFailed) {
    try {
      excel.copy('Menu Items', 'README');
      Sheet readme = excel['README'];
  // readme.clear(); // Not supported by excel package

      CellStyle titleStyle = CellStyle(
        bold: true,
        fontSize: 16,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.white,
      );

      CellStyle headerStyle = CellStyle(bold: true, fontSize: 12);

      // Title
      readme.cell(CellIndex.indexByString('A1')).value = TextCellValue('📋 MENU EXPORT - README');
      readme.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
      readme.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

      int row = 3;

      // Export info
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('Export Date: ${DateTime.now().toString().split('.')[0]}');
      row += 2;

      // Folder structure
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('📁 FOLDER STRUCTURE:');
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = headerStyle;
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('├── menu_items.xlsx (this file)');
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('└── images/ (folder with item images)');
      row += 2;

      // Image stats
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('📊 IMAGE EXPORT STATISTICS:');
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = headerStyle;
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('✅ Images Successfully Exported: $imagesExported');
      row++;
      if (imagesFailed > 0) {
        readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
          TextCellValue('⚠️  Images Failed: $imagesFailed');
        row++;
      }
      row++;

      // Instructions
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('📖 HOW TO REIMPORT:');
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = headerStyle;
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('1. Keep the folder structure intact');
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('2. Keep images folder in same location as Excel file');
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('3. Use Import function in the app');
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('4. Select the menu_items.xlsx file');
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('5. Images will be loaded automatically');
      row += 2;

      // Notes
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('⚠️  IMPORTANT NOTES:');
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = headerStyle;
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('• Image File column shows: images/[filename].jpg');
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('• Empty Image File = no image for that item');
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('• Do not rename images folder or files');
      row++;
      readme.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        TextCellValue('• Keep all files together when moving/copying');

  // Column width setting is not supported by the excel package. This line is removed.
    } catch (e) {
      debugPrint('Error creating README sheet: $e');
    }
  }

  /// Import menu items with images from folder
  static Future<List<MenuItem>?> importMenuItemsWithImages({
    String? category,
  }) async {
    try {
      // Pick Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('No file selected');
        return null;
      }

      final file = result.files.first;
      String excelFilePath;

      if (kIsWeb) {
        debugPrint('Web platform not supported for image import');
        return null;
      } else {
        if (file.path == null) {
          debugPrint('Error: File path is null');
          return null;
        }
        excelFilePath = file.path!;
      }

      // Read Excel file
      final fileObj = File(excelFilePath);
      final bytes = await fileObj.readAsBytes();
      var excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        debugPrint('Error: No sheets found in Excel file');
        return null;
      }

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        debugPrint('Error: Sheet is empty');
        return null;
      }

      // Get the folder containing the Excel file
      final excelFolder = path.dirname(excelFilePath);
      final imagesFolder = path.join(excelFolder, 'images');
      
      debugPrint('📁 Excel file: $excelFilePath');
      debugPrint('📁 Looking for images in: $imagesFolder');

      // Check if images folder exists
      final imagesFolderDir = Directory(imagesFolder);
      if (!await imagesFolderDir.exists()) {
        debugPrint('⚠️  Warning: images folder not found at $imagesFolder');
      }

      return _parseExcelSheetWithImages(sheet, category, imagesFolder);
    } catch (e) {
      debugPrint('❌ Error importing Excel file with images: $e');
      return null;
    }
  }

  /// Parse Excel sheet with image file references
  static Future<List<MenuItem>> _parseExcelSheetWithImages(Sheet sheet, String? defaultCategory, String imagesFolder) async {
    List<MenuItem> items = [];
    int imagesLoaded = 0;
    int imagesMissing = 0;
    
    // Skip header row (index 0)
    for (int i = 1; i < sheet.rows.length; i++) {
      try {
        final row = sheet.rows[i];
        
        if (row.isEmpty || _isRowEmpty(row)) continue;

        // Columns: Name, Price, Category, Available, Image File
        final name = _getCellValue(row, 0)?.trim();
        final priceStr = _getCellValue(row, 1);
        final categoryFromExcel = _getCellValue(row, 2)?.trim();
        final availableStr = _getCellValue(row, 3);
        final imageFileName = _getCellValue(row, 4)?.trim() ?? '';

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
          
          if (await imageFile.exists()) {
            try {
              final imageBytes = await imageFile.readAsBytes();
              final base64String = base64Encode(imageBytes);
              imageUrl = 'data:image/jpeg;base64,$base64String';
              imagesLoaded++;
              debugPrint('✅ Loaded image: $cleanFileName');
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
          category: itemCategory,
          imageUrl: imageUrl,
          isAvailable: isAvailable,
        );

        items.add(item);
        debugPrint('✅ Parsed item: $name');
      } catch (e) {
        debugPrint('❌ Error parsing row $i: $e');
        continue;
      }
    }

    debugPrint('📊 Import complete: ${items.length} items, $imagesLoaded images loaded, $imagesMissing images missing');
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

  // Column width setting is not supported by the excel package. These lines are removed.

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
      
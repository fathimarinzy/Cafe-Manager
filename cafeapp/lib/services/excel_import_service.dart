import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/menu_item.dart';

class ExcelImportService {
  /// Pick and read Excel file
  static Future<List<MenuItem>?> importMenuItemsFromExcel({
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
      List<int> bytes;

      // Read file bytes
      if (kIsWeb) {
        if (file.bytes == null) {
          debugPrint('Error: File bytes are null');
          return null;
        }
        bytes = file.bytes!;
      } else {
        if (file.path == null) {
          debugPrint('Error: File path is null');
          return null;
        }
        final fileObj = File(file.path!);
        bytes = await fileObj.readAsBytes();
      }

      // Parse Excel file
      var excel = Excel.decodeBytes(bytes);
      
      // Get the first sheet
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

      return _parseExcelSheet(sheet, category);
    } catch (e) {
      debugPrint('Error importing Excel file: $e');
      return null;
    }
  }

  /// Parse Excel sheet and convert to MenuItem list
  static List<MenuItem> _parseExcelSheet(Sheet sheet, String? defaultCategory) {
    List<MenuItem> items = [];
    
    // Skip header row (index 0)
    for (int i = 1; i < sheet.rows.length; i++) {
      try {
        final row = sheet.rows[i];
        
        // Skip empty rows
        if (row.isEmpty || _isRowEmpty(row)) continue;

        // Expected columns: Name, Price, Category, Available (optional), Image URL (optional)
        final name = _getCellValue(row, 0)?.trim();
        final priceStr = _getCellValue(row, 1);
        final categoryFromExcel = _getCellValue(row, 2)?.trim();
        final availableStr = _getCellValue(row, 3);
        final imageUrl = _getCellValue(row, 4)?.trim() ?? '';

        // Validate required fields
        if (name == null || name.isEmpty) {
          debugPrint('Row $i: Skipping - Name is empty');
          continue;
        }

        if (priceStr == null || priceStr.isEmpty) {
          debugPrint('Row $i: Skipping - Price is empty for item "$name"');
          continue;
        }

        // Parse price
        double? price;
        try {
          price = double.parse(priceStr.replaceAll(RegExp(r'[^\d.]'), ''));
        } catch (e) {
          debugPrint('Row $i: Skipping - Invalid price "$priceStr" for item "$name"');
          continue;
        }

        // Determine category: use from Excel if available, otherwise use default
        String itemCategory = defaultCategory ?? '';
        if (categoryFromExcel != null && categoryFromExcel.isNotEmpty) {
          itemCategory = categoryFromExcel;
        }

        if (itemCategory.isEmpty) {
          debugPrint('Row $i: Skipping - No category specified for item "$name"');
          continue;
        }

        // Parse availability (default to true)
        bool isAvailable = true;
        if (availableStr != null && availableStr.isNotEmpty) {
          final availableLower = availableStr.toLowerCase();
          isAvailable = availableLower == 'yes' || 
                       availableLower == 'true' || 
                       availableLower == '1' ||
                       availableLower == 'available';
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
        debugPrint('Row $i: Successfully parsed item "$name"');
      } catch (e) {
        debugPrint('Error parsing row $i: $e');
        continue;
      }
    }

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

  /// Create sample Excel template
  static Future<String?> createSampleTemplate() async {
    try {
      var excel = Excel.createExcel();
      
      // Get or create sheet
      String sheetName = 'Menu Items';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
      Sheet sheet = excel[sheetName];

      // Define header style
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
      sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Image URL (Optional)');

      // Apply header style
      for (var col in ['A', 'B', 'C', 'D', 'E']) {
        sheet.cell(CellIndex.indexByString('${col}1')).cellStyle = headerStyle;
      }

      // Add sample data
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

      sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('Caesar Salad');
      sheet.cell(CellIndex.indexByString('B4')).value = const DoubleCellValue(8.99);
      sheet.cell(CellIndex.indexByString('C4')).value = TextCellValue('Salads');
      sheet.cell(CellIndex.indexByString('D4')).value = TextCellValue('Yes');
      sheet.cell(CellIndex.indexByString('E4')).value = TextCellValue('');

      // Save file
      var fileBytes = excel.save();
      if (fileBytes == null) {
        debugPrint('Error: Failed to generate Excel file');
        return null;
      }

      // Save to downloads or user-selected location
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

  /// Validate Excel file format
  static Future<Map<String, dynamic>> validateExcelFile(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        return {
          'isValid': false,
          'error': 'No sheets found in Excel file',
        };
      }

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        return {
          'isValid': false,
          'error': 'Sheet is empty',
        };
      }

      // Check if header row exists
      final headerRow = sheet.rows[0];
      if (headerRow.length < 3) {
        return {
          'isValid': false,
          'error': 'Missing required columns. Expected: Name, Price, Category',
        };
      }

      // Count valid data rows
      int validRows = 0;
      for (int i = 1; i < sheet.rows.length; i++) {
        if (!_isRowEmpty(sheet.rows[i])) {
          validRows++;
        }
      }

      return {
        'isValid': true,
        'rowCount': validRows,
        'sheetName': sheetName,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': 'Error reading Excel file: ${e.toString()}',
      };
    }
  }
}
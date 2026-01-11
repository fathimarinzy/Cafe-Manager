import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/foundation.dart';

// Helper class to send RAW BYTES to a Windows Printer using Win32 API
// Bypasses driver rendering to avoid truncation or margin issues
class WindowsRawPrinter {
  
  static bool printBytes({required String printerName, required List<int> bytes, String jobName = "Raw Print Job"}) {
    final phPrinter = calloc<HANDLE>();
    final pDocInfo = calloc<DOC_INFO_1>();
    bool result = false;

    try {
      // 1. Open Printer
      final pPrinterName = printerName.toNativeUtf16();
      final openSuccess = OpenPrinter(pPrinterName, phPrinter, nullptr);
      calloc.free(pPrinterName);
      
      if (openSuccess == 0) {
        debugPrint('Failed to open printer: $printerName (Error: ${GetLastError()})');
        return false;
      }

      // 2. Start Document
      final pDocName = jobName.toNativeUtf16();
      final pDataType = 'RAW'.toNativeUtf16();
      
      pDocInfo.ref.pDocName = pDocName;
      pDocInfo.ref.pOutputFile = nullptr;
      pDocInfo.ref.pDatatype = pDataType;

      final dwJob = StartDocPrinter(phPrinter.value, 1, pDocInfo);
      
      calloc.free(pDocName);
      calloc.free(pDataType);

      if (dwJob == 0) {
        debugPrint('Failed to start document job (Error: ${GetLastError()})');
        ClosePrinter(phPrinter.value);
        return false;
      }

      // 3. Start Page
      if (StartPagePrinter(phPrinter.value) == 0) {
         debugPrint('Failed to start page (Error: ${GetLastError()})');
         EndDocPrinter(phPrinter.value);
         ClosePrinter(phPrinter.value);
         return false;
      }

      // 4. Write Bytes
      final pBytes = calloc<Uint8>(bytes.length);
      for (var i = 0; i < bytes.length; i++) {
        pBytes[i] = bytes[i];
      }
      
      final dwBytesWritten = calloc<DWORD>();
      final writeSuccess = WritePrinter(
        phPrinter.value, 
        pBytes, 
        bytes.length, 
        dwBytesWritten
      );

      if (writeSuccess == 0) {
        debugPrint('Failed to write bytes to printer (Error: ${GetLastError()})');
        EndPagePrinter(phPrinter.value);
        EndDocPrinter(phPrinter.value);
        ClosePrinter(phPrinter.value);
        
        calloc.free(pBytes);
        calloc.free(dwBytesWritten);
        return false;
      }
      
      final written = dwBytesWritten.value;
      if (written != bytes.length) {
        debugPrint('Warning: Only wrote $written bytes out of ${bytes.length}');
      }

      calloc.free(pBytes);
      calloc.free(dwBytesWritten);

      // 5. End Page & Doc
      EndPagePrinter(phPrinter.value);
      EndDocPrinter(phPrinter.value);
      ClosePrinter(phPrinter.value);
      
      result = true;
      debugPrint('Successfully sent ${bytes.length} bytes to $printerName');
      
    } catch (e) {
      debugPrint('Exception in WindowsRawPrinter: $e');
      result = false;
    } finally {
      calloc.free(phPrinter);
      calloc.free(pDocInfo);
    }
    
    return result;
  }
}

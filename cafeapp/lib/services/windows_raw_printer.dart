import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/foundation.dart';

// Helper class to send RAW BYTES to a Windows Printer using Win32 API
// Bypasses driver rendering to avoid truncation or margin issues
class WindowsRawPrinter {
  
  // Check if printer is online and ready
  static bool isPrinterOnline(String printerName) {
    final phPrinter = calloc<HANDLE>();
    bool isOnline = false;

    try {
      final pPrinterName = printerName.toNativeUtf16();
      final openSuccess = OpenPrinter(pPrinterName, phPrinter, nullptr);
      calloc.free(pPrinterName);
      
      if (openSuccess == 0) {
        debugPrint('Failed to open printer for status check: $printerName');
        return false;
      }

      // Get printer info to check status
      final pcbNeeded = calloc<DWORD>();
      final pcReturned = calloc<DWORD>();

      // First call to get required buffer size
      GetPrinter(phPrinter.value, 2, nullptr, 0, pcbNeeded);
      
      final cbBuf = pcbNeeded.value;
      final pPrinter = calloc<Uint8>(cbBuf);
      
      final getSuccess = GetPrinter(
        phPrinter.value,
        2,
        pPrinter,
        cbBuf,
        pcbNeeded,
      );

      if (getSuccess != 0) {
        final printerInfo = pPrinter.cast<PRINTER_INFO_2>();
        final status = printerInfo.ref.Status;
        
        // Check if printer is offline, error, or paused
        // PRINTER_STATUS_OFFLINE = 0x00000080
        // PRINTER_STATUS_ERROR = 0x00000002  
        // PRINTER_STATUS_PAUSED = 0x00000001
        // PRINTER_STATUS_PAPER_OUT = 0x00000010
        const offlineFlags = 0x00000080 | 0x00000002 | 0x00000001 | 0x00000010;
        
        if ((status & offlineFlags) == 0) {
          isOnline = true;
          debugPrint('Printer $printerName is online (status: $status)');
        } else {
          debugPrint('Printer $printerName is offline or has error (status: $status)');
        }
      }

      calloc.free(pPrinter);
      calloc.free(pcbNeeded);
      calloc.free(pcReturned);
      
      ClosePrinter(phPrinter.value);
    } catch (e) {
      debugPrint('Exception checking printer status: $e');
      isOnline = false;
    } finally {
      calloc.free(phPrinter);
    }

    return isOnline;
  }
  
  static bool printBytes({required String printerName, required List<int> bytes, String jobName = "Raw Print Job"}) {
    // Check if printer is online first
    if (!isPrinterOnline(printerName)) {
      debugPrint('Printer $printerName is offline or unavailable');
      return false;
    }
    
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

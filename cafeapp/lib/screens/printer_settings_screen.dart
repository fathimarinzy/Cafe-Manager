import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'dart:async';
import '../services/thermal_printer_service.dart';
import '../utils/app_localization.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> with SingleTickerProviderStateMixin {
  // Receipt Printer controllers
  final _receiptIpController = TextEditingController();
  final _receiptPortController = TextEditingController();
  
  // KOT Printer controllers
  final _kotIpController = TextEditingController();
  final _kotPortController = TextEditingController();
  
  bool _isLoading = true;
  bool _isTestingReceipt = false;
  bool _isTestingKot = false;
  bool _isDiscovering = false;
  bool _kotPrinterEnabled = true;
  
  // NEW: System Printer State
  String _receiptPrinterType = ThermalPrinterService.printerTypeNetwork;
  String _kotPrinterType = ThermalPrinterService.printerTypeNetwork;
  String? _selectedReceiptSystemPrinter;
  String? _selectedKotSystemPrinter;
  List<Printer> _systemPrinters = [];
  bool _isLoadingSystemPrinters = false;
  
  late TabController _tabController;
  final List<Map<String, String>> _discoveredPrinters = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
    _loadSystemPrinters();
  }

  @override
  void dispose() {
    _receiptIpController.dispose();
    _receiptPortController.dispose();
    _kotIpController.dispose();
    _kotPortController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSystemPrinters() async {
    setState(() {
      _isLoadingSystemPrinters = true;
    });
    
    try {
      final printers = await Printing.listPrinters();
      setState(() {
        _systemPrinters = printers;
        _isLoadingSystemPrinters = false;
      });
    } catch (e) {
      debugPrint('Error loading system printers: $e');
      setState(() {
        _isLoadingSystemPrinters = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load Receipt Printer settings
      final receiptIp = await ThermalPrinterService.getPrinterIp();
      final receiptPort = await ThermalPrinterService.getPrinterPort();
      final receiptType = await ThermalPrinterService.getReceiptPrinterType();
      final receiptSystemName = await ThermalPrinterService.getReceiptSystemPrinterName();
      
      // Load KOT Printer settings
      final kotIp = await ThermalPrinterService.getKotPrinterIp();
      final kotPort = await ThermalPrinterService.getKotPrinterPort();
      final kotEnabled = await ThermalPrinterService.isKotPrinterEnabled();
      final kotType = await ThermalPrinterService.getKotPrinterType();
      final kotSystemName = await ThermalPrinterService.getKotSystemPrinterName();
      
      setState(() {
        _receiptIpController.text = receiptIp;
        _receiptPortController.text = receiptPort.toString();
        
        _kotIpController.text = kotIp;
        _kotPortController.text = kotPort.toString();
        _kotPrinterEnabled = kotEnabled;
        
        // Load types
        _receiptPrinterType = receiptType;
        _kotPrinterType = kotType;
        _selectedReceiptSystemPrinter = receiptSystemName;
        _selectedKotSystemPrinter = kotSystemName;
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage("Error loading printer settings".tr());
    }
  }

  Future<void> _discoverPrinters() async {
    setState(() {
      _isDiscovering = true;
      _discoveredPrinters.clear();
    });

    try {
      // Get the current network information
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      
      if (wifiIP == null) {
        _showErrorMessage("Not connected to Wi-Fi".tr());
        return;
      }

      // Extract the subnet
      final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
      
      // List to store discovered printers
      final List<Future<void>> scanTasks = [];

      // Scan IP range (1-254)
      for (int i = 1; i < 255; i++) {
        final ip = '$subnet.$i';
        
        // Only scan if it's not the current device's IP
        if (ip != wifiIP) {
          scanTasks.add(_checkPrinterAtIP(ip));
        }
      }

      // Wait for all scan tasks to complete
      await Future.wait(scanTasks);

      // Update UI with discovered printers
      setState(() {
        _isDiscovering = false;
      });

      // Show results
      if (_discoveredPrinters.isEmpty) {
        _showErrorMessage("No printers found".tr());
      } else {
        _showDiscoveredPrintersDialog();
      }
    } catch (e) {
      setState(() {
        _isDiscovering = false;
      });
      _showErrorMessage("Error discovering printers".tr());
    }
  }

  Future<void> _checkPrinterAtIP(String ip) async {
    try {
      // Try to connect to the standard thermal printer port
      final socket = await Socket.connect(ip, 9100, timeout: const Duration(milliseconds: 500));
      
      // If connection successful, we consider it a potential printer
      socket.destroy();
      
      // Add to discovered printers list
      setState(() {
        _discoveredPrinters.add({
          'ip': ip,
          'port': '9100',
        });
      });
    } catch (_) {
      // Ignore connection failures
    }
  }

  void _showDiscoveredPrintersDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        // Get screen orientation and size
        final screenSize = MediaQuery.of(context).size;
        final isLandscape = screenSize.width > screenSize.height;
        final dialogWidth = isLandscape ? screenSize.width * 0.7 : screenSize.width * 0.9;
        final dialogHeight = isLandscape ? screenSize.height * 0.8 : screenSize.height * 0.6;
        
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.wifi,
                      color: Colors.blue.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Discovered Printers'.tr(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close'.tr(),
                    ),
                  ],
                ),
                
                const Divider(height: 24),
                
                // Subtitle
                if (_discoveredPrinters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Select a printer to configure:'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                
                // Printers List
                Expanded(
                  child: _discoveredPrinters.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No printers found'.tr(),
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Make sure printers are connected to the same network'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _discoveredPrinters.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final printer = _discoveredPrinters[index];
                            return _buildPrinterTile(ctx, printer, isLandscape);
                          },
                        ),
                ),
                
                // Footer buttons
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _discoverPrinters(); // Refresh search
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text('Refresh'.tr()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Close'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrinterTile(BuildContext ctx, Map<String, String> printer, bool isLandscape) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Printer info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.print,
                  color: Colors.blue.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Network Printer'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IP: ${printer['ip']} | Port: ${printer['port']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons - responsive layout
          if (isLandscape)
            // Landscape: side by side
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _receiptIpController.text = printer['ip']!;
                        _receiptPortController.text = printer['port']!;
                      });
                      Navigator.of(ctx).pop();
                      
                      // Show confirmation
                      _showSuccessMessage('Receipt printer configured with ${printer['ip']}'.tr());
                    },
                    icon: const Icon(Icons.receipt, size: 18),
                    label: Text('Set as Receipt Printer'.tr()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.blue.shade700),
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _kotIpController.text = printer['ip']!;
                        _kotPortController.text = printer['port']!;
                        _kotPrinterEnabled = true; // Auto-enable KOT printer
                      });
                      Navigator.of(ctx).pop();
                      
                      // Show confirmation
                      _showSuccessMessage('KOT printer configured with ${printer['ip']}'.tr());
                    },
                    icon: const Icon(Icons.restaurant_menu, size: 18),
                    label: Text('Set as KOT Printer'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            )
          else
            // Portrait: stacked
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _receiptIpController.text = printer['ip']!;
                        _receiptPortController.text = printer['port']!;
                      });
                      Navigator.of(ctx).pop();
                      
                      // Show confirmation
                      _showSuccessMessage('Receipt printer configured with ${printer['ip']}'.tr());
                    },
                    icon: const Icon(Icons.receipt, size: 18),
                    label: Text('Set as Receipt Printer'.tr()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.blue.shade700),
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _kotIpController.text = printer['ip']!;
                        _kotPortController.text = printer['port']!;
                        _kotPrinterEnabled = true; // Auto-enable KOT printer
                      });
                      Navigator.of(ctx).pop();
                      
                      // Show confirmation
                      _showSuccessMessage('KOT printer configured with ${printer['ip']}'.tr());
                    },
                    icon: const Icon(Icons.restaurant_menu, size: 18),
                    label: Text('Set as KOT Printer'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _saveReceiptPrinterSettings() async {
    // Validation based on printer type
    if (_receiptPrinterType == ThermalPrinterService.printerTypeNetwork) {
      if (!_validateIpAddress(_receiptIpController.text)) {
        _showErrorMessage("Please enter a valid IP address for Receipt Printer".tr());
        return;
      }

      final portText = _receiptPortController.text.trim();
      final port = int.tryParse(portText);
      if (port == null || port <= 0 || port > 65535) {
        _showErrorMessage("Please enter a valid port number (1-65535) for Receipt Printer".tr());
        return;
      }
    } else {
      // System printer 
      if (_selectedReceiptSystemPrinter == null) {
        _showErrorMessage("Please select a printer".tr());
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save Type
      await ThermalPrinterService.setReceiptPrinterType(_receiptPrinterType);
      
      // Save details based on type
      if (_receiptPrinterType == ThermalPrinterService.printerTypeNetwork) {
        await ThermalPrinterService.savePrinterIp(_receiptIpController.text.trim());
        final port = int.parse(_receiptPortController.text.trim());
        await ThermalPrinterService.savePrinterPort(port);
      } else {
        await ThermalPrinterService.setReceiptSystemPrinterName(_selectedReceiptSystemPrinter);
      }
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showSuccessMessage("Receipt printer settings saved".tr());
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage("Error saving receipt printer settings".tr());
    }
  }

  Future<void> _saveKotPrinterSettings() async {
    // Validation based on printer type
    if (_kotPrinterType == ThermalPrinterService.printerTypeNetwork) {
      if (!_validateIpAddress(_kotIpController.text)) {
        _showErrorMessage("Please enter a valid IP address for KOT Printer".tr());
        return;
      }

      final portText = _kotPortController.text.trim();
      final port = int.tryParse(portText);
      if (port == null || port <= 0 || port > 65535) {
        _showErrorMessage("Please enter a valid port number (1-65535) for KOT Printer".tr());
        return;
      }
    } else {
      // System printer
      if (_selectedKotSystemPrinter == null) {
        _showErrorMessage("Please select a printer".tr());
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ThermalPrinterService.setKotPrinterEnabled(_kotPrinterEnabled);
      await ThermalPrinterService.setKotPrinterType(_kotPrinterType);
      
      if (_kotPrinterType == ThermalPrinterService.printerTypeNetwork) {
        await ThermalPrinterService.saveKotPrinterIp(_kotIpController.text.trim());
        final port = int.parse(_kotPortController.text.trim());
        await ThermalPrinterService.saveKotPrinterPort(port);
      } else {
        await ThermalPrinterService.setKotSystemPrinterName(_selectedKotSystemPrinter);
      }
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showSuccessMessage("KOT printer settings saved".tr());
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage("Error saving KOT printer settings".tr());
    }
  }

  Future<void> _testReceiptConnection() async {
    setState(() {
      _isTestingReceipt = true;
    });

    try {
      final connected = await ThermalPrinterService.testConnection(
        type: _receiptPrinterType,
        ip: _receiptIpController.text.trim(),
        port: int.tryParse(_receiptPortController.text.trim()),
        systemPrinterName: _selectedReceiptSystemPrinter,
      );
      
      if (!mounted) return;
      
      setState(() {
        _isTestingReceipt = false;
      });
      
      if (connected) {
        _showSuccessMessage("Successfully connected to receipt printer".tr());
      } else {
        if (_receiptPrinterType == ThermalPrinterService.printerTypeNetwork) {
          _showErrorMessage("Failed to connect to receipt printer. Please check IP address and port.".tr());
        } else {
          _showErrorMessage("Failed to test system printer. Please check if the printer is on and drivers are installed.".tr());
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTestingReceipt = false;
      });
      _showErrorMessage("Error testing receipt printer connection".tr());
    }
  }

  Future<void> _testKotConnection() async {
    setState(() {
      _isTestingKot = true;
    });

    try {
      final connected = await ThermalPrinterService.testKotConnection(
        type: _kotPrinterType,
        ip: _kotIpController.text.trim(),
        port: int.tryParse(_kotPortController.text.trim()),
        systemPrinterName: _selectedKotSystemPrinter,
      );
      
      if (!mounted) return;
      
      setState(() {
        _isTestingKot = false;
      });
      
      if (connected) {
        _showSuccessMessage("Successfully connected to KOT printer".tr());
      } else {
        if (_kotPrinterType == ThermalPrinterService.printerTypeNetwork) {
          _showErrorMessage("Failed to connect to KOT printer. Please check IP address and port.".tr());
        } else {
          _showErrorMessage("Failed to test KOT system printer. Please check if the printer is on and drivers are installed.".tr());
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTestingKot = false;
      });
      _showErrorMessage("Error testing KOT printer connection".tr());
    }
  }

  bool _validateIpAddress(String ip) {
    final RegExp ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    );
    return ipRegex.hasMatch(ip);
  }

  // FIXED: Cross-platform toast replacement using SnackBar
  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Printer Settings'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: [
            Tab(
              icon: const Icon(Icons.receipt_long),
              text: 'Receipt Printer'.tr(),
            ),
            Tab(
              icon: const Icon(Icons.restaurant),
              text: 'KOT Printer'.tr(),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading settings...'.tr()),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReceiptPrinterTab(),
                _buildKotPrinterTab(),
              ],
            ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children, Widget? trailing}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
      ),
    );
  }

  Widget _buildReceiptPrinterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Configuration',
            icon: Icons.settings,
            children: [
              // Connection Type
              Text(
                'Connection Type'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: ButtonTheme(
                    alignedDropdown: true,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _receiptPrinterType,
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        DropdownMenuItem(
                          value: ThermalPrinterService.printerTypeNetwork,
                          child: Row(
                            children: [
                              const Icon(Icons.wifi, size: 20, color: Colors.grey),
                              const SizedBox(width: 12),
                              Text('Network (WiFi/Ethernet)'.tr()),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: ThermalPrinterService.printerTypeSystem,
                          child: Row(
                            children: [
                              const Icon(Icons.usb, size: 20, color: Colors.grey),
                              const SizedBox(width: 12),
                              Text('System Printer (USB/Driver)'.tr()),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _receiptPrinterType = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_receiptPrinterType == ThermalPrinterService.printerTypeNetwork) ...[
                _buildTextField(
                  controller: _receiptIpController,
                  label: 'Printer IP Address'.tr(),
                  hint: 'e.g., 192.168.1.100',
                  icon: Icons.dns,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _receiptPortController,
                  label: 'Printer Port'.tr(),
                  hint: 'e.g., 9100',
                  icon: Icons.numbers,
                  keyboardType: TextInputType.number,
                ),
              ] else ...[
                 Text(
                  'Select Printer'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                if (_isLoadingSystemPrinters)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ))
                else if (_systemPrinters.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No system printers found.'.tr(),
                            style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadSystemPrinters,
                          child: Text('Refresh'.tr()),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: ButtonTheme(
                              alignedDropdown: true,
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedReceiptSystemPrinter,
                                hint: Text('Choose a printer'.tr()),
                                borderRadius: BorderRadius.circular(12),
                                items: _systemPrinters.map((printer) {
                                  return DropdownMenuItem(
                                    value: printer.name,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.print, size: 18, color: Colors.grey),
                                        const SizedBox(width: 8),
                                        Flexible(child: Text(printer.name, overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedReceiptSystemPrinter = value;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.blue),
                          onPressed: _loadSystemPrinters,
                          tooltip: 'Refresh Printers'.tr(),
                        ),
                      ),
                    ],
                  ),
              ],
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveReceiptPrinterSettings,
                  icon: const Icon(Icons.save),
                  label: Text('Save Configuration'.tr()),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          _buildSectionCard(
            title: 'Connection Status'.tr(),
            icon: Icons.network_check,
            children: [
               Row(
                 children: [
                   Expanded(
                     child: OutlinedButton.icon(
                      onPressed: _isTestingReceipt ? null : _testReceiptConnection,
                      icon: _isTestingReceipt 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.wifi_tethering),
                      label: Text(_isTestingReceipt ? 'Testing...' : 'Test Connection'.tr()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.blue.shade700),
                        foregroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                                     ),
                   ),
                   if (_receiptPrinterType == ThermalPrinterService.printerTypeNetwork) ...[
                     const SizedBox(width: 12),
                     Expanded(
                       child: OutlinedButton.icon(
                        onPressed: _isDiscovering ? null : _discoverPrinters,
                        icon: _isDiscovering 
                           ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                           : const Icon(Icons.search),
                        label: Text(_isDiscovering ? 'Scanning...' : 'Scan Printers'.tr()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                       ),
                     ),
                   ],
                 ],
               ),
            ],
          ),

          _buildHelpSection(),
        ],
      ),
    );
  }


  Widget _buildKotPrinterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'KOT Status',
            icon: Icons.power_settings_new,
            children: [
              SwitchListTile(
                title: Text('Enable KOT Printer'.tr(), style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('Print kitchen orders to separate printer'.tr()),
                value: _kotPrinterEnabled,
                onChanged: (bool value) {
                  setState(() {
                    _kotPrinterEnabled = value;
                  });
                },
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kotPrinterEnabled ? Colors.green.shade50 : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _kotPrinterEnabled ? Icons.check_circle : Icons.cancel,
                    color: _kotPrinterEnabled ? Colors.green : Colors.grey,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),

          if (_kotPrinterEnabled) ...[
            _buildSectionCard(
              title: 'Configuration',
              icon: Icons.settings,
              children: [
                Text(
                  'Connection Type'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _kotPrinterType,
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          DropdownMenuItem(
                            value: ThermalPrinterService.printerTypeNetwork,
                            child: Row(
                              children: [
                                const Icon(Icons.wifi, size: 20, color: Colors.grey),
                                const SizedBox(width: 12),
                                Text('Network (WiFi/Ethernet)'.tr()),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThermalPrinterService.printerTypeSystem,
                            child: Row(
                              children: [
                                const Icon(Icons.usb, size: 20, color: Colors.grey),
                                const SizedBox(width: 12),
                                Text('System Printer (USB/Driver)'.tr()),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _kotPrinterType = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                if (_kotPrinterType == ThermalPrinterService.printerTypeNetwork) ...[
                  _buildTextField(
                    controller: _kotIpController,
                    label: 'Printer IP Address'.tr(),
                    hint: 'e.g., 192.168.1.101',
                    icon: Icons.dns,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _kotPortController,
                    label: 'Printer Port'.tr(),
                    hint: 'e.g., 9100',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                  ),
                ] else ...[
                   Text(
                    'Select Printer'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingSystemPrinters)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_systemPrinters.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No system printers found.'.tr(),
                              style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadSystemPrinters,
                            child: Text('Refresh'.tr()),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: ButtonTheme(
                                alignedDropdown: true,
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedKotSystemPrinter,
                                  hint: Text('Choose a printer'.tr()),
                                  borderRadius: BorderRadius.circular(12),
                                  items: _systemPrinters.map((printer) {
                                    return DropdownMenuItem(
                                      value: printer.name,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.print, size: 18, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Flexible(child: Text(printer.name, overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedKotSystemPrinter = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.blue),
                            onPressed: _loadSystemPrinters,
                            tooltip: 'Refresh Printers'.tr(),
                          ),
                        ),
                      ],
                    ),
                ],
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveKotPrinterSettings,
                    icon: const Icon(Icons.save),
                    label: Text('Save Configuration'.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            _buildSectionCard(
              title: 'Connection Status'.tr(),
              icon: Icons.network_check,
              children: [
                 Row(
                   children: [
                     Expanded(
                       child: OutlinedButton.icon(
                        onPressed: (_kotPrinterEnabled && !_isTestingKot) ? _testKotConnection : null,
                        icon: _isTestingKot 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Icon(Icons.wifi_tethering),
                        label: Text(_isTestingKot ? 'Testing...' : 'Test Connection'.tr()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: _kotPrinterEnabled ? Colors.blue.shade700 : Colors.grey),
                          foregroundColor: _kotPrinterEnabled ? Colors.blue.shade700 : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                       ),
                     ),
                   if (_kotPrinterType == ThermalPrinterService.printerTypeNetwork) ...[
                     const SizedBox(width: 12),
                     Expanded(
                       child: OutlinedButton.icon(
                        onPressed: (_kotPrinterEnabled && !_isDiscovering) ? _discoverPrinters : null,
                        icon: _isDiscovering 
                           ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                           : const Icon(Icons.search),
                        label: Text(_isDiscovering ? 'Scanning...' : 'Scan Printers'.tr()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                       ),
                     ),
                   ],
                   ],
                 ),
              ],
            ),
          ],
          
          _buildHelpSection(),
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      color: Colors.blue.shade50.withAlpha(128),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.help_outline, color: Colors.blue.shade700),
          title: Text(
            'Troubleshooting Guide'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
             const Divider(),
             const SizedBox(height: 8),
             _buildHelpItem(
               '1. Network Printers', 
               'Ensure the printer and this device are on the same WiFi network. Determine the printer\'s IP address from its self-test page.'
             ),
             _buildHelpItem(
               '2. Port Number', 
               'Standard port for thermal printers is 9100. Only change this if you have configured your printer differently.'
             ),
             _buildHelpItem(
               '3. System Printers', 
               'Connect your USB printer and ensure drivers are installed. If it doesn\'t appear in the list, try refreshing or restarting the app.'
             ),
             _buildHelpItem(
               '4. KOT Printing', 
               'You can use the same physical printer for both Receipt and KOT by entering the same settings in both tabs.'
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  description.tr(),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
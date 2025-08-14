import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:network_info_plus/network_info_plus.dart';
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
  
  late TabController _tabController;
  final List<Map<String, String>> _discoveredPrinters = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
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

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load Receipt Printer settings
      final receiptIp = await ThermalPrinterService.getPrinterIp();
      final receiptPort = await ThermalPrinterService.getPrinterPort();
      
      // Load KOT Printer settings
      final kotIp = await ThermalPrinterService.getKotPrinterIp();
      final kotPort = await ThermalPrinterService.getKotPrinterPort();
      final kotEnabled = await ThermalPrinterService.isKotPrinterEnabled();
      
      setState(() {
        _receiptIpController.text = receiptIp;
        _receiptPortController.text = receiptPort.toString();
        _kotIpController.text = kotIp;
        _kotPortController.text = kotPort.toString();
        _kotPrinterEnabled = kotEnabled;
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
        _showErrorMessage("No printers discovered".tr());
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
      builder: (ctx) => AlertDialog(
        title: Text('Discovered Printers'.tr()),
        content: SizedBox(
          width: double.infinity,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _discoveredPrinters.length,
            itemBuilder: (context, index) {
              final printer = _discoveredPrinters[index];
              return ListTile(
                title: Text('IP: ${printer['ip']}'),
                subtitle: Text('Port: ${printer['port']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      child: Text('Receipt'.tr()),
                      onPressed: () {
                        setState(() {
                          _receiptIpController.text = printer['ip']!;
                          _receiptPortController.text = printer['port']!;
                        });
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      child: Text('KOT'.tr()),
                      onPressed: () {
                        setState(() {
                          _kotIpController.text = printer['ip']!;
                          _kotPortController.text = printer['port']!;
                        });
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _saveReceiptPrinterSettings() async {
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

    setState(() {
      _isLoading = true;
    });

    try {
      await ThermalPrinterService.savePrinterIp(_receiptIpController.text.trim());
      await ThermalPrinterService.savePrinterPort(port);
      
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

    setState(() {
      _isLoading = true;
    });

    try {
      await ThermalPrinterService.saveKotPrinterIp(_kotIpController.text.trim());
      await ThermalPrinterService.saveKotPrinterPort(port);
      await ThermalPrinterService.setKotPrinterEnabled(_kotPrinterEnabled);
      
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
      final connected = await ThermalPrinterService.testConnection();
      
      if (!mounted) return;
      
      setState(() {
        _isTestingReceipt = false;
      });
      
      if (connected) {
        _showSuccessMessage("Successfully connected to receipt printer".tr());
      } else {
        _showErrorMessage("Failed to connect to receipt printer. Please check IP address and port.".tr());
      }
    } catch (e) {
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
      final connected = await ThermalPrinterService.testKotConnection();
      
      if (!mounted) return;
      
      setState(() {
        _isTestingKot = false;
      });
      
      if (connected) {
        _showSuccessMessage("Successfully connected to KOT printer".tr());
      } else {
        _showErrorMessage("Failed to connect to KOT printer. Please check IP address and port.".tr());
      }
    } catch (e) {
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

  void _showErrorMessage(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  void _showSuccessMessage(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Printer Settings'.tr()),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.receipt),
              text: 'Receipt Printer'.tr(),
            ),
            Tab(
              icon: const Icon(Icons.restaurant_menu),
              text: 'KOT Printer'.tr(),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReceiptPrinterTab(),
                _buildKotPrinterTab(),
              ],
            ),
    );
  }

  Widget _buildReceiptPrinterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Printer icon and title
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt,
                  size: 60,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 8),
                Text(
                  'Receipt Printer Configuration'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure your receipt printer'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // IP Address Field
          Text(
            'Printer IP Address'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _receiptIpController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'e.g., 192.168.1.100'.tr(),
              helperText: 'Enter the IP address of your printer'.tr(),
            ),
            keyboardType: TextInputType.number,
          ),
          
          const SizedBox(height: 24),
          
          // Port Field
          Text(
            'Printer Port'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _receiptPortController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'e.g., 9100'.tr(),
              helperText: 'Default port for most thermal printers is 9100'.tr(),
            ),
            keyboardType: TextInputType.number,
          ),
          
          const SizedBox(height: 32),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveReceiptPrinterSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Save Settings'.tr(),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Test Connection Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isTestingReceipt ? null : _testReceiptConnection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: _isTestingReceipt
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Testing Connection...'.tr()),
                      ],
                    )
                  : Text(
                      'Test Connection'.tr(),
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          _buildHelpSection(),
        ],
      ),
    );
  }

  Widget _buildKotPrinterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Printer icon and title
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 60,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 8),
                Text(
                  'KOT Printer Configuration'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure your KOT printer'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // KOT Printer Enable/Disable
          Card(
            child: SwitchListTile(
              title: Text('Enable KOT Printer'.tr()),
              subtitle: Text('Print kitchen orders to separate printer'.tr()),
              value: _kotPrinterEnabled,
              onChanged: (bool value) {
                setState(() {
                  _kotPrinterEnabled = value;
                });
              },
              secondary: Icon(
                _kotPrinterEnabled ? Icons.print : Icons.print_disabled,
                color: _kotPrinterEnabled ? Colors.green : Colors.grey,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // IP Address Field
          Text(
            'Printer IP Address'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _kotPrinterEnabled ? Colors.black : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _kotIpController,
            enabled: _kotPrinterEnabled,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'e.g., 192.168.1.101'.tr(),
              helperText: 'Enter the IP address of your printer'.tr(),
            ),
            keyboardType: TextInputType.number,
          ),
          
          const SizedBox(height: 24),
          
          // Port Field
          Text(
            'Printer Port'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _kotPrinterEnabled ? Colors.black : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _kotPortController,
            enabled: _kotPrinterEnabled,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'e.g., 9100'.tr(),
              helperText: 'Default port for most thermal printers is 9100'.tr(),
            ),
            keyboardType: TextInputType.number,
          ),
          
          const SizedBox(height: 32),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _kotPrinterEnabled ? _saveKotPrinterSettings : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Save Settings'.tr(),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Test Connection Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _kotPrinterEnabled && !_isTestingKot ? _testKotConnection : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: _isTestingKot
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Testing Connection...'.tr()),
                      ],
                    )
                  : Text(
                       'Test Connection'.tr(),
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          _buildHelpSection(),
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
    return Column(
      children: [
        // Printer Discovery Section
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Printer Discovery'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Automatically find network printers on your local network.'.tr(),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isDiscovering ? null : _discoverPrinters,
                    icon: _isDiscovering
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _isDiscovering
                          ? 'Discovering...'.tr()
                          : 'Discover Printers'.tr(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),

        // Help section
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Printer Setup Help'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '1. Make sure your printers are connected to the same WiFi network as this tablet'.tr(),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '2. Enter the printer\'s IP address (check your printer settings or router)'.tr(),
                   style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '3. Port 9100 is the standard port for most network printers'.tr(),
                   style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '4. Click "Test Connection" to verify the printer is working'.tr(),
                   style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '5. You can use the same printer for both purposes with different IP addresses or disable KOT printing'.tr(),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
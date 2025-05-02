import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:io';
import 'dart:async';
import '../services/thermal_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  bool _isLoading = true;
  bool _isTesting = false;
  bool _isDiscovering = false;
  final List<Map<String, String>> _discoveredPrinters = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ip = await ThermalPrinterService.getPrinterIp();
      final port = await ThermalPrinterService.getPrinterPort();
      
      setState(() {
        _ipController.text = ip;
        _portController.text = port.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage("Error loading printer settings");
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
        _showErrorMessage("Not connected to Wi-Fi");
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
        _showErrorMessage("No printers discovered");
      } else {
        _showDiscoveredPrintersDialog();
      }
    } catch (e) {
      setState(() {
        _isDiscovering = false;
      });
      _showErrorMessage("Error discovering printers: $e");
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
        title: const Text('Discovered Printers'),
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
                trailing: ElevatedButton(
                  child: const Text('Select'),
                  onPressed: () {
                    // Set the selected printer's IP and port
                    setState(() {
                      _ipController.text = printer['ip']!;
                      _portController.text = printer['port']!;
                    });
                    Navigator.of(ctx).pop();
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
  Future<void> _saveSettings() async {
    if (!_validateIpAddress(_ipController.text)) {
      _showErrorMessage("Please enter a valid IP address");
      return;
    }

    final portText = _portController.text.trim();
    final port = int.tryParse(portText);
    if (port == null || port <= 0 || port > 65535) {
      _showErrorMessage("Please enter a valid port number (1-65535)");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ThermalPrinterService.savePrinterIp(_ipController.text.trim());
      await ThermalPrinterService.savePrinterPort(port);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showSuccessMessage("Printer settings saved");
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage("Error saving printer settings");
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
    });

    try {
      final connected = await ThermalPrinterService.testConnection();
      
      if (!mounted) return;
      
      setState(() {
        _isTesting = false;
      });
      
      if (connected) {
        _showSuccessMessage("Successfully connected to printer");
      } else {
        _showErrorMessage("Failed to connect to printer. Please check IP address and port.");
      }
    } catch (e) {
      setState(() {
        _isTesting = false;
      });
      _showErrorMessage("Error testing printer connection: $e");
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
        title: const Text('Printer Settings'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Printer icon and title
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.print,
                          size: 60,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Thermal Printer Configuration',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Text(
                        //   'Configure your Everycom EC901C Printer',
                        //   style: TextStyle(
                        //     fontSize: 14,
                        //     color: Colors.grey.shade700,
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // IP Address Field
                  const Text(
                    'Printer IP Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 192.168.1.100',
                      helperText: 'Enter the IP address of your network printer',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Port Field
                  const Text(
                    'Printer Port',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 9100',
                      helperText: 'Default port for most thermal printers is 9100',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Save Settings',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Test Connection Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isTesting ? null : _testConnection,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: _isTesting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Testing Connection...'),
                              ],
                            )
                          : const Text(
                              'Test Connection',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  // New Printer Discovery Section
                  const SizedBox(height: 24),
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
                              const Text(
                                'Printer Discovery',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Automatically find network printers on your local network.',
                            style: TextStyle(fontSize: 14),
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
                                    ? 'Discovering...'
                                    : 'Discover Printers',
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
                              const Text(
                                'Printer Setup Help',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. Make sure your Everycom EC901C printer is connected to the same WiFi network as this tablet',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '2. Enter the printer\'s IP address (check your printer settings or router)',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '3. Port 9100 is the standard port for most network printers',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '4. Click "Test Connection" to verify the printer is working',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
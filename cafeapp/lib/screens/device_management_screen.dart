// lib/screens/device_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_model.dart';
// import '../models/device_link_model.dart';
import '../services/device_sync_service.dart';
import '../utils/app_localization.dart';
import 'dart:async';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  bool _isLoading = false;
  List<DeviceModel> _devices = [];
  String _companyId = '';
  String _currentDeviceId = '';
  bool _syncEnabled = false;
  bool _isMainDevice = false;
  // List<DeviceLinkCode> _activeLinkCodes = [];

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _companyId = prefs.getString('company_id') ?? '';
      _currentDeviceId = prefs.getString('device_id') ?? '';
      _syncEnabled = prefs.getBool('device_sync_enabled') ?? false;
      _isMainDevice = prefs.getBool('is_main_device') ?? false;

       // DEBUG: Print all SharedPreferences keys
      final allKeys = prefs.getKeys();
      debugPrint('All SharedPreferences keys: $allKeys');
      debugPrint('Company ID: $_companyId');
      debugPrint('Device ID: $_currentDeviceId');

      if (_companyId.isNotEmpty) {
        _devices = await DeviceSyncService.getCompanyDevices(_companyId);
        
        if (_isMainDevice) {
          // _activeLinkCodes = await DeviceSyncService.getActiveLinkCodes();
        }
      }
    } catch (e) {
      debugPrint('Error loading device info: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSetupMainDeviceDialog() async {
    final nameController = TextEditingController(text: 'Main Counter');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Set Up Main Device'.tr()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Main Device Name'.tr(),
                  hintText: 'e.g., Main Counter, Reception'.tr(),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter device name'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  'This device will be set as the main device . You can generate codes to link other devices.'.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
            child: Text('Set as Main Device'.tr()),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);

      final response = await DeviceSyncService.registerMainDevice(
        deviceName: nameController.text,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        if (response['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Main device set successfully!'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          _loadDeviceInfo();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to set main device'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showLinkStaffDeviceDialog() async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Link Device'.tr()),
        content: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: '6-Digit Code'.tr(),
                      hintText: 'Enter code from main device'.tr(),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.pin),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the code'.tr();
                      }
                      if (value.length != 6) {
                        return 'Code must be 6 digits'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Device Name'.tr(),
                      hintText: 'e.g., Waiter Tablet 1'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter device name'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Text(
                      'Get the 6-digit code from the main device to link this device.'.tr(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
            child: Text('Link Device'.tr()),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);

      final response = await DeviceSyncService.linkDeviceWithCode(
        code: codeController.text,
        staffDeviceName: nameController.text,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        if (response['success']) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text('Device Linked!'.tr()),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Successfully linked to:'.tr()),
                  const SizedBox(height: 8),
                  Text(
                    response['mainDeviceName'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('This device will now sync with all devices.'.tr()),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Restart the app to load new company data
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/dashboard',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                  child: Text('Continue'.tr()),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to link device'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _generateLinkCode() async {
    setState(() => _isLoading = true);

    final response = await DeviceSyncService.generateLinkCode();

    setState(() => _isLoading = false);

    if (mounted) {
      if (response['success']) {
        final code = response['code'] as String;
        final expiresAt = DateTime.parse(response['expiresAt'] as String);
        
        _showGeneratedCodeDialog(code, expiresAt);
        _loadDeviceInfo(); // Refresh to show new code
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to generate code'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGeneratedCodeDialog(String code, DateTime expiresAt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Link Code'.tr()),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    'Link Code:'.tr(),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Expires in 24 hours'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enter this code on the device to link it to this Main Device.'.tr(),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Code copied to clipboard'.tr()),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text('Copy Code'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _setMainDevice(DeviceModel device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Main Device'.tr()),
        content: Text(
          'Set "${device.deviceName}" as the main device? This device will be able to generate link codes for devices.'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
            child: Text('Confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);

      final response = await DeviceSyncService.setMainDevice(
        deviceId: device.id,
        companyId: _companyId,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        if (response['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Main device set successfully'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          _loadDeviceInfo();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to set main device'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeDevice(DeviceModel device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove Device'.tr()),
        content: Text(
          'Remove "${device.deviceName}" from syncing? This device will no longer receive anything.'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Remove'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);

      final response = await DeviceSyncService.removeDevice(
        device.id,
        _companyId,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        if (response['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device removed successfully'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          _loadDeviceInfo();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to remove device'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleSync(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('device_sync_enabled', enabled);

    setState(() => _syncEnabled = enabled);

    if (enabled && _companyId.isNotEmpty) {
      DeviceSyncService.startAutoSync(_companyId);
    } else {
      DeviceSyncService.stopAutoSync();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled 
                ? 'Device sync enabled'.tr()
                : 'Device sync disabled'.tr(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('Device Management'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shouldShowInitialSetup()
              ? _buildInitialSetup()
              : _buildDeviceList(),
    );
  }
  bool _shouldShowInitialSetup() {
    // Show initial setup if:
    // 1. Device is not registered (no company_id)
    // 2. OR Device is not established yet (no devices found AND not marked as main)
    return _companyId.isEmpty || (_devices.isEmpty && !_isMainDevice);

  }
  Widget _buildInitialSetup() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Device Setup'.tr(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose how to set up this device:'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _showSetupMainDeviceDialog,
                icon: const Icon(Icons.star),
                label: Text('Set as Main Device'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _showLinkStaffDeviceDialog,
                icon: const Icon(Icons.link),
                label: Text('Link to Main Device'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                  side: BorderSide(color: Colors.blue[700]!),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sync Toggle Card
        Card(
          child: SwitchListTile(
            value: _syncEnabled,
            onChanged: _toggleSync,
            title: Text('Enable Device Sync'.tr()),
            subtitle: Text(
              'Automatically sync across all devices'.tr(),
            ),
            secondary: Icon(
              Icons.sync,
              color: _syncEnabled ? Colors.green : Colors.grey,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Main Device Actions (only show if this is main device)
        if (_isMainDevice) ...[
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Main Device Actions'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generateLinkCode,
                      icon: const Icon(Icons.add),
                      label: Text('Generate Code for Device'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  
                  // Show active link codes
                  // if (_activeLinkCodes.isNotEmpty) ...[
                  //   const SizedBox(height: 16),
                  //   Text(
                  //     'Active Link Codes:'.tr(),
                  //     style: const TextStyle(
                  //       fontSize: 14,
                  //       fontWeight: FontWeight.w600,
                  //     ),
                  //   ),
                  //   const SizedBox(height: 8),
                  //   ..._activeLinkCodes.map((code) => _buildLinkCodeItem(code)),
                  // ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Devices Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Registered Devices'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isMainDevice)
              OutlinedButton.icon(
                onPressed: _showLinkStaffDeviceDialog,
                icon: const Icon(Icons.link),
                label: Text('Link Device'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Devices List
        if (_devices.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.devices, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No devices registered yet'.tr(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._devices.map((device) => _buildDeviceCard(device)),
      ],
    );
  }

  // Widget _buildLinkCodeItem(DeviceLinkCode code) {
  //   final timeLeft = code.expiresAt.difference(DateTime.now());
  //   final hoursLeft = timeLeft.inHours;
    
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 8),
  //     padding: const EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(
  //         color: code.isUsed ? Colors.grey : Colors.blue[300]!,
  //       ),
  //     ),
  //     child: Row(
  //       children: [
  //         Text(
  //           code.code,
  //           style: TextStyle(
  //             fontSize: 18,
  //             fontWeight: FontWeight.bold,
  //             color: code.isUsed ? Colors.grey : Colors.blue[900],
  //             letterSpacing: 2,
  //           ),
  //         ),
  //         const Spacer(),
  //         if (code.isUsed)
  //           Container(
  //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //             decoration: BoxDecoration(
  //               color: Colors.grey[300],
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: Text(
  //               'USED'.tr(),
  //               style: const TextStyle(
  //                 fontSize: 10,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           )
  //         else
  //           Text(
  //             '${hoursLeft}h left'.tr(),
  //             style: TextStyle(
  //               fontSize: 12,
  //               color: Colors.grey[600],
  //             ),
  //           ),
  //         const SizedBox(width: 8),
  //         IconButton(
  //           icon: const Icon(Icons.copy, size: 18),
  //           onPressed: () {
  //             Clipboard.setData(ClipboardData(text: code.code));
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               SnackBar(
  //                 content: Text('Code copied'.tr()),
  //                 duration: const Duration(seconds: 1),
  //               ),
  //             );
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildDeviceCard(DeviceModel device) {
    final isCurrentDevice = device.id == _currentDeviceId;
    final deviceIcon = _getDeviceIcon(device.deviceType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: device.isMainDevice 
                ? Colors.blue[100]
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            deviceIcon,
            color: device.isMainDevice 
                ? Colors.blue[700]
                : Colors.grey[700],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.deviceName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (device.isMainDevice)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'MAIN'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isCurrentDevice)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'THIS DEVICE'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Type: ${device.deviceType}'.tr()),
            if (device.lastSyncedAt != null)
              Text(
                'Last synced: ${_formatDateTime(device.lastSyncedAt!)}'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            if (!device.isMainDevice && _isMainDevice)
              PopupMenuItem(
                onTap: () => Future.delayed(
                  Duration.zero,
                  () => _setMainDevice(device),
                ),
                child: Row(
                  children: [
                    // const Icon(Icons.star, size: 20),
                    const SizedBox(width: 8),
                    // Text('Set as Main'.tr()),
                  ],
                ),
              ),
            if (_isMainDevice || device.id == _currentDeviceId)
              PopupMenuItem(
                onTap: () => Future.delayed(
                  Duration.zero,
                  () => _removeDevice(device),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delete, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    Text('Remove'.tr(), style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'android':
        return Icons.phone_android;
      case 'windows':
        return Icons.desktop_windows;
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
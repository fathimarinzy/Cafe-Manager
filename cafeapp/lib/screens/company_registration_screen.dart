import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localization.dart';
import 'dashboard_screen.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/license_service.dart';
import '../services/offline_sync_service.dart'; // NEW: Import sync service

class CompanyRegistrationScreen extends StatefulWidget {
  const CompanyRegistrationScreen({super.key});

  @override
  State<CompanyRegistrationScreen> createState() => _CompanyRegistrationScreenState();
}

class _CompanyRegistrationScreenState extends State<CompanyRegistrationScreen> {
  // Registration key controllers
  final List<TextEditingController> _keyControllers = List.generate(5, (index) => TextEditingController());
  final List<FocusNode> _keyFocusNodes = List.generate(5, (index) => FocusNode());
  
  // Business information controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _secondBusinessNameController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController();
  final TextEditingController _businessPhoneController = TextEditingController();
  final TextEditingController _businessEmailController = TextEditingController(); // NEW: Email controller

  // Focus nodes for business info
  final FocusNode _businessNameFocus = FocusNode();
  final FocusNode _secondBusinessNameFocus = FocusNode();
  final FocusNode _businessAddressFocus = FocusNode();
  final FocusNode _businessPhoneFocus = FocusNode();
  final FocusNode _businessEmailFocus = FocusNode(); // NEW: Email focus node
  
  bool _isLoading = false;
  bool _showWarning = false;
  
  // The correct keys
  final List<String> _correctKeys = ['M2P016', 'A2L018', 'A2Z023', 'B2CAFE', 'M1U985'];

  @override
  void initState() {
    super.initState();

     // Add listeners to business info fields to show warning
    _businessNameController.addListener(_onBusinessInfoChanged);
    _secondBusinessNameController.addListener(_onBusinessInfoChanged);
    _businessAddressController.addListener(_onBusinessInfoChanged);
    _businessPhoneController.addListener(_onBusinessInfoChanged);
    _businessEmailController.addListener(_onBusinessInfoChanged); // NEW: Add email listener
  }

  @override
  void dispose() {
    // Dispose controllers
    for (var controller in _keyControllers) {
      controller.dispose();
    }
    for (var focusNode in _keyFocusNodes) {
      focusNode.dispose();
    }

    _businessNameController.dispose();
    _secondBusinessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose(); // NEW: Dispose email controller

    _businessNameFocus.dispose();
    _secondBusinessNameFocus.dispose();
    _businessAddressFocus.dispose();
    _businessPhoneFocus.dispose();
    _businessEmailFocus.dispose(); // NEW: Dispose email focus node

    super.dispose();
  }

  void _onBusinessInfoChanged() {
    if (!_showWarning && (_businessNameController.text.isNotEmpty || 
        _secondBusinessNameController.text.isNotEmpty ||
        _businessAddressController.text.isNotEmpty || 
        _businessPhoneController.text.isNotEmpty ||
        _businessEmailController.text.isNotEmpty)) { // NEW: Include email check
      setState(() {
        _showWarning = true;
      });
    }
  }

  void _onKeyChanged(int index, String value) {
    // Auto move to next field when current field is filled
    if (value.length >= 6 && index < 4) {
      _keyFocusNodes[index + 1].requestFocus();
    }
    
    // Move to previous field when current field is empty
    if (value.isEmpty && index > 0) {
      _keyFocusNodes[index - 1].requestFocus();
    }
  }

  bool _validateKeys() {
    for (int i = 0; i < 5; i++) {
      if (_keyControllers[i].text.trim().toUpperCase() != _correctKeys[i]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _registerCompany() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Validate keys
      if (!_validateKeys()) {
        _showErrorMessage('Invalid registration keys. Please check your keys and try again.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Save company registration locally FIRST
      final prefs = await SharedPreferences.getInstance();
      
      // Ensure device ID exists
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        // Generate device ID if missing
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', deviceId);
        debugPrint('Generated new device ID: $deviceId');
      }
      
      await prefs.setBool('company_registered', true);
      await prefs.setBool('device_registered', true);

      // Set license start date
      await LicenseService.setLicenseStartDate();

      // Save business information to SharedPreferences
      await prefs.setString('business_name', _businessNameController.text.trim());
      await prefs.setString('second_business_name', _secondBusinessNameController.text.trim());
      await prefs.setString('business_address', _businessAddressController.text.trim());
      await prefs.setString('business_phone', _businessPhoneController.text.trim());
      await prefs.setString('business_email', _businessEmailController.text.trim()); // NEW: Save email

      // Update SettingsProvider
      if (mounted) {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        await settingsProvider.saveAllSettings(
          businessName: _businessNameController.text.trim(),
          secondBusinessName: _secondBusinessNameController.text.trim(),
          businessAddress: _businessAddressController.text.trim(),
          businessPhone: _businessPhoneController.text.trim(),
          businessEmail: _businessEmailController.text.trim(), // NEW: Pass email to settings
        );
      }

      // IMPORTANT: Wait a moment to ensure all data is saved
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mark offline registration data as pending sync
      await OfflineSyncService.markOfflineDataPending();
      
      // Debug: Check what data is actually stored before attempting sync
      await OfflineSyncService.debugStoredRegistrationData();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration successful'.tr()),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to dashboard after a brief delay
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false, // Remove all previous routes
          );
        }
      }
      
      // Attempt Firebase sync AFTER navigation (non-blocking)
      _attemptFirebaseSyncDelayed();
      
    } catch (e) {
      debugPrint('Error registering company: $e');
      _showErrorMessage('Registration failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // NEW: Delayed Firebase sync attempt (after navigation completes)
  void _attemptFirebaseSyncDelayed() async {
    // Wait a bit more to ensure navigation is complete and data is fully saved
    await Future.delayed(const Duration(seconds: 2));
    
    try {
      debugPrint('Attempting delayed Firebase sync...');
       
      // Debug: Check stored data again before sync
      await OfflineSyncService.debugStoredRegistrationData();
      
      final syncResult = await OfflineSyncService.checkAndSync();
      
      if (syncResult['success']) {
        debugPrint('Delayed sync successful: ${syncResult['message']}');
      } else if (syncResult['noConnection'] == true) {
        debugPrint('No internet connection - will sync when available');
        // Start auto-sync for when connection is restored
        OfflineSyncService.autoSync();
      } else {
        debugPrint('Delayed sync failed: ${syncResult['message']}');
        // Start auto-sync to retry later
        OfflineSyncService.autoSync();
      }
    } catch (e) {
      debugPrint('Error during delayed Firebase sync: $e');
      // Start auto-sync to retry later
      OfflineSyncService.autoSync();
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // title: Text('Company Registration'.tr()),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: 'Register Your ',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          TextSpan(
                            text: 'Company',
                            style: TextStyle(color: Colors.blue[700]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Offline Registration',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Registration Keys Section
              Text(
                'Enter Your Registration Key :'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 5 Key Input Fields
              Row(
                children: List.generate(5, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index < 4 ? 8.0 : 0,
                      ),
                      child: TextField(
                        controller: _keyControllers[index],
                        focusNode: _keyFocusNodes[index],
                        onChanged: (value) => _onKeyChanged(index, value),
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        inputFormatters: [
                          UpperCaseTextFormatter(),
                        ],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          // hintText: _correctKeys[index],
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 40),
              
              // Business Information Section
              Text(
                'Business Information :'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              
              const SizedBox(height: 16),
               // Warning message
              if (_showWarning) ...[
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
                          'Warning: Once you register, you won\'t be able to edit your business information again.'.tr(),
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
                           
              const SizedBox(height: 16),

              // Business Name
              TextField(
                controller: _businessNameController,
                focusNode: _businessNameFocus,
                decoration: InputDecoration(
                  labelText: 'Business Name'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              // Second Business Name field
              TextField(
                controller: _secondBusinessNameController,
                focusNode: _secondBusinessNameFocus,
                decoration: InputDecoration(
                  labelText: 'Second Business Name (Optional)'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                  ),
                  // prefixIcon: const Icon(Icons.business_center),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Business Address
              TextField(
                controller: _businessAddressController,
                focusNode: _businessAddressFocus,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Address'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Business Phone
              TextField(
                controller: _businessPhoneController,
                focusNode: _businessPhoneFocus,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // NEW: Business Email
              TextField(
                controller: _businessEmailController,
                focusNode: _businessEmailFocus,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Register Button
              Center(
                child: SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerCompany,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Register'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // NEW: Sync Status Info (optional, for debugging/user info)
              FutureBuilder<Map<String, dynamic>>(
                future: OfflineSyncService.getSyncStatus(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  
                  final syncStatus = snapshot.data!;
                  if (!syncStatus['hasPendingData']) return const SizedBox.shrink();
                  
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_upload, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        // Expanded(
                        //   child: Text(
                        //     'Data will be synced to cloud when internet is available'.tr(),
                        //     style: TextStyle(
                        //       color: Colors.blue[700],
                        //       fontSize: 12,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom text formatter to convert to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
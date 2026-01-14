import 'package:cafeapp/providers/logo_provider.dart';
import 'package:cafeapp/services/connectivity_monitor.dart';
import 'package:cafeapp/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localization.dart';
import 'dashboard_screen.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/license_service.dart';
import '../services/offline_sync_service.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/logo_service.dart';

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

  
// SECURE: Get keys from environment variables with fallbacks
  List<String> get _correctKeys {
    try {
      return [
        dotenv.env['REGISTRATION_KEY_1'] ?? _getFallbackKey(0),
        dotenv.env['REGISTRATION_KEY_2'] ?? _getFallbackKey(1),
        dotenv.env['REGISTRATION_KEY_3'] ?? _getFallbackKey(2),
        dotenv.env['REGISTRATION_KEY_4'] ?? _getFallbackKey(3),
        dotenv.env['REGISTRATION_KEY_5'] ?? _getFallbackKey(4),
      ];
    } catch (e) {
      debugPrint('Error loading registration keys from environment: $e');
      // Fallback to build-time environment variables if .env fails
      return [
        const String.fromEnvironment('REGISTRATION_KEY_1', defaultValue: ''),
        const String.fromEnvironment('REGISTRATION_KEY_2', defaultValue: ''),
        const String.fromEnvironment('REGISTRATION_KEY_3', defaultValue: ''),
        const String.fromEnvironment('REGISTRATION_KEY_4', defaultValue: ''),
        const String.fromEnvironment('REGISTRATION_KEY_5', defaultValue: ''),
      ].where((key) => key.isNotEmpty).toList();
    }
  }

  // Fallback method (should not contain real keys in production)
  String _getFallbackKey(int index) {
    debugPrint('WARNING: Using fallback key for index $index. Check environment variables.');
    // Return empty string to force proper environment setup
    return '';
  }

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
  debugPrint('=== REGISTRATION DEBUG START ===');
  debugPrint('Build Mode: ${kReleaseMode ? "RELEASE" : "DEBUG"}');
  debugPrint('Platform: ${Platform.operatingSystem}');
  
  // Validate that all key fields are filled
  for (int i = 0; i < 5; i++) {
    if (_keyControllers[i].text.trim().isEmpty) {
      _showErrorMessage('Please fill all registration key fields');
      return;
    }
  }
  
  // Validate that business information is filled
  if (_businessNameController.text.trim().isEmpty ||
      _businessAddressController.text.trim().isEmpty ||
      _businessPhoneController.text.trim().isEmpty) {
    _showErrorMessage('Please fill all business information fields');
    return;
  }
  
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
    
    debugPrint('✅ Registration keys validated');

    // Save company registration locally FIRST
    final prefs = await SharedPreferences.getInstance();
    
    // Ensure device ID exists
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', deviceId);
      debugPrint('✅ Generated new device ID: $deviceId');
    } else {
      debugPrint('✅ Using existing device ID: $deviceId');
    }
    // Generate company ID for offline registration
    String? companyId = prefs.getString('company_id');
    if (companyId == null || companyId.isEmpty) {
      companyId = 'offline_company_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('company_id', companyId); // 🆕 STORE COMPANY ID
      debugPrint('✅ Generated offline company ID: $companyId');
    }else {
      debugPrint('✅ Using existing company ID: $companyId');
    }

    
    await prefs.setBool('company_registered', true);
    await prefs.setBool('device_registered', true);
    // 🆕 Enable sync by default for offline registration (if internet becomes available later)
    await prefs.setBool('device_sync_enabled', true);
    debugPrint('✅ Set registration flags in SharedPreferences');

    // Set license start date
    await LicenseService.setLicenseStartDate();
    debugPrint('✅ License start date set');

    // Save business information to SharedPreferences
    await prefs.setString('business_name', _businessNameController.text.trim());
    await prefs.setString('second_business_name', _secondBusinessNameController.text.trim());
    await prefs.setString('business_address', _businessAddressController.text.trim());
    await prefs.setString('business_phone', _businessPhoneController.text.trim());
    await prefs.setString('business_email', _businessEmailController.text.trim());
    
    debugPrint('✅ Business info saved to SharedPreferences:');
    debugPrint('   Name: ${_businessNameController.text.trim()}');
    debugPrint('   Address: ${_businessAddressController.text.trim()}');
    debugPrint('   Phone: ${_businessPhoneController.text.trim()}');
    debugPrint('   Email: ${_businessEmailController.text.trim()}');

    // Update SettingsProvider
    if (mounted) {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.saveAllSettings(
        businessName: _businessNameController.text.trim(),
        secondBusinessName: _secondBusinessNameController.text.trim(),
        businessAddress: _businessAddressController.text.trim(),
        businessPhone: _businessPhoneController.text.trim(),
        businessEmail: _businessEmailController.text.trim(),
      );
      debugPrint('✅ Settings provider updated');
    }

    // IMPORTANT: Wait a moment to ensure all data is saved
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mark offline registration data as pending sync
    await OfflineSyncService.markOfflineDataPending();
    debugPrint('✅ Marked offline data as pending sync');
    
    // Debug: Check what data is actually stored before attempting sync
    await OfflineSyncService.debugStoredRegistrationData();
    
    // Check Firebase availability
    await FirebaseService.ensureInitialized();
    final isFirebaseAvailable = FirebaseService.isFirebaseAvailable;
    debugPrint('🔥 Firebase available: $isFirebaseAvailable');
    
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
          (route) => false,
        );
      }
    }
    
    // Attempt Firebase sync AFTER navigation (non-blocking)
    _attemptFirebaseSyncDelayed();
    
  } catch (e) {
    debugPrint('❌ Error registering company: $e');
    debugPrint('   Error type: ${e.runtimeType}');
    debugPrint('   Stack trace: ${StackTrace.current}');
    _showErrorMessage('Registration failed. Please try again.');
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  debugPrint('=== REGISTRATION DEBUG END ===');
}

// Also update the _attemptFirebaseSyncDelayed method:

void _attemptFirebaseSyncDelayed() async {
  debugPrint('=== PORTABLE SYNC START ===');
  
  // Longer delay for portable version initialization
  final delayDuration = (Platform.isWindows || Platform.isMacOS || Platform.isLinux) 
      ? const Duration(seconds: 5) 
      : const Duration(seconds: 2);
  
  await Future.delayed(delayDuration);
  
  try {
    debugPrint('🔄 Portable: Attempting Firebase sync...');
    
    // Ensure Firebase is properly initialized for portable
    await FirebaseService.ensureInitialized();
    final isFirebaseAvailable = FirebaseService.isFirebaseAvailable;
    debugPrint('🔥 Portable Firebase available: $isFirebaseAvailable');
    
    if (!isFirebaseAvailable) {
      debugPrint('⚠️ Portable: Firebase not available - starting monitor');
      OfflineSyncService.autoSync();
      ConnectivityMonitor.instance.startMonitoring();
      return;
    }
    
    // 🆕 More aggressive sync for portable version
    debugPrint('🔄 Portable: Force syncing registration...');
    final syncResult = await OfflineSyncService.forceSyncOfflineRegistration();
    
    debugPrint('📊 Portable Sync result: ${syncResult['success']}');
    
    if (syncResult['success']) {
      debugPrint('✅ Portable: Sync successful!');
      // 🆕 Verify the data actually reached Firestore
      await _verifyFirestoreSync();
    } else {
      debugPrint('❌ Portable: Sync failed - ${syncResult['message']}');
      // Start aggressive monitoring for portable
      OfflineSyncService.autoSync();
      ConnectivityMonitor.instance.startMonitoring();
    }
  } catch (e) {
    debugPrint('❌ Portable: Sync error - $e');
    // Ensure monitoring starts even on error
    ConnectivityMonitor.instance.startMonitoring();
  }
  
  debugPrint('=== PORTABLE SYNC END ===');
}

// 🆕 ADD THIS METHOD to verify Firestore sync
Future<void> _verifyFirestoreSync() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? '';
    
    if (deviceId.isEmpty) return;
    
    // Wait a moment for Firestore to process
    await Future.delayed(const Duration(seconds: 2));
    
    // Check if data actually exists in Firestore
    final firestoreCheck = await FirebaseService.getOfflineRegistration(deviceId);
    
    if (firestoreCheck['isRegistered']) {
      debugPrint('✅ PORTABLE CONFIRMED: Business data in Firestore!');
    } else {
      debugPrint('⚠️ PORTABLE: Data not in Firestore yet - sync pending');
    }
  } catch (e) {
    debugPrint('Error verifying Firestore: $e');
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
              const SizedBox(height: 16),

              // Logo Upload Section
              Text(
                'Business Logo (Optional):'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

             // WRAP IN CONSUMER TO LISTEN TO LOGO CHANGES
              Consumer<LogoProvider>(
                builder: (context, logoProvider, child) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Logo preview or placeholder
                        if (logoProvider.hasLogo && logoProvider.logoPath != null) ...[
                          // Use the logoPath directly with timestamp key to force refresh
                          Image.file(
                            File(logoProvider.logoPath!),
                            key: ValueKey('logo_${logoProvider.lastUpdateTimestamp}'),
                            height: 100,
                            width: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Error loading logo: $error');
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 60, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text('Error loading logo'.tr(), style: const TextStyle(fontSize: 12)),
                                ],
                              );
                            },
                          ),
                        ] else ...[
                          Icon(Icons.image, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No logo uploaded'.tr(),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                        
                        const SizedBox(height: 12),
                        
                         // Upload or Remove button (centered, normal width)
                          logoProvider.hasLogo
                              ? OutlinedButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('Remove Logo'.tr()),
                                        content: Text('Are you sure you want to remove the logo?'.tr()),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: Text('Cancel'.tr()),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                            child: Text('Remove'.tr()),
                                          ),
                                        ],
                                      ),
                                    );
                                    
                                    if (confirm == true) {
                                      // Use LogoProvider's removeLogo method
                                      await logoProvider.removeLogo();
                                    }
                                  },
                                  icon: const Icon(Icons.delete),
                                  label: Text('Remove Logo'.tr()),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () async {
                                    final success = await LogoService.pickAndSaveLogo(context);
                                    if (success) {
                                      // Update LogoProvider to trigger UI refresh
                                      await logoProvider.updateLogo();
                                    }
                                  },
                                  icon: const Icon(Icons.upload),
                                  label: Text('Upload Logo'.tr()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                        ],
                      ),
                    );
                  },
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
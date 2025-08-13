import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ADDED: For Timestamp
import '../utils/app_localization.dart';
import '../services/firebase_service.dart';
import 'dashboard_screen.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class OnlineCompanyRegistrationScreen extends StatefulWidget {
  const OnlineCompanyRegistrationScreen({super.key});

  @override
  State<OnlineCompanyRegistrationScreen> createState() => _OnlineCompanyRegistrationScreenState();
}

class _OnlineCompanyRegistrationScreenState extends State<OnlineCompanyRegistrationScreen> {
  // Registration key controllers
  final List<TextEditingController> _keyControllers = List.generate(5, (index) => TextEditingController());
  final List<FocusNode> _keyFocusNodes = List.generate(5, (index) => FocusNode());

  // Business information controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _secondBusinessNameController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController();
  final TextEditingController _businessPhoneController = TextEditingController();

  // Focus nodes for business info
  final FocusNode _businessNameFocus = FocusNode();
  final FocusNode _secondBusinessNameFocus = FocusNode();
  final FocusNode _businessAddressFocus = FocusNode();
  final FocusNode _businessPhoneFocus = FocusNode();

  bool _isLoading = false;
  bool _showWarning = false;
  bool _showContactInfo = false; // Show contact info instead of generated keys
  bool _isGeneratingKeys = false; // Loading state for key generation
  DateTime? _keysGeneratedAt; // ADDED: Track when keys were generated
  DateTime? _keysExpireAt; // ADDED: Track when keys expire
  
  // NEW: Contact information
  final String _supportPhone = "+968 7184 0022"; // Replace with actual support number
  final String _supportEmail = "AI@simsai.tech"; // Replace with actual support email

  @override
  void initState() {
    super.initState();

    // Add listeners to business info fields to show warning
    _businessNameController.addListener(_onBusinessInfoChanged);
    _secondBusinessNameController.addListener(_onBusinessInfoChanged);
    _businessAddressController.addListener(_onBusinessInfoChanged);
    _businessPhoneController.addListener(_onBusinessInfoChanged);

    // ADDED: Check for existing pending keys when screen loads
    _checkExistingPendingKeys();
  }

  // ADDED: Check if device already has pending keys
  Future<void> _checkExistingPendingKeys() async {
    try {
      // Get device ID
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = FirebaseService.generateDeviceId();
        await prefs.setString('device_id', deviceId);
        return; // New device, no pending keys
      }

      // Check for existing pending registration
      final result = await FirebaseService.getPendingRegistration(deviceId);
      
      if (result['success']) {
        // Found existing pending keys, show contact info directly
        setState(() {
          _showContactInfo = true;
          // ADDED: Store key timestamps for better UX
          if (result['createdAt'] != null) {
            _keysGeneratedAt = (result['createdAt'] as Timestamp).toDate();
          }
          if (result['expiresAt'] != null) {
            _keysExpireAt = (result['expiresAt'] as Timestamp).toDate();
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You already have pending registration keys. Please use those keys to complete registration.'.tr()),
              backgroundColor: Colors.grey[600],
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (result['isExpired'] == true) {
        // Keys expired, user can generate new ones
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your previous registration keys have expired. You can generate new ones.'.tr()),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      // If no pending keys found, user can generate new ones (default state)
      
    } catch (e) {
      debugPrint('Error checking existing pending keys: $e');
      // If error occurs, allow user to generate keys (default state)
    }
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

    _businessNameFocus.dispose();
    _secondBusinessNameFocus.dispose();
    _businessAddressFocus.dispose();
    _businessPhoneFocus.dispose();

    super.dispose();
  }

  void _onBusinessInfoChanged() {
    if (!_showWarning && (_businessNameController.text.isNotEmpty || 
        _secondBusinessNameController.text.isNotEmpty || 
        _businessAddressController.text.isNotEmpty || 
        _businessPhoneController.text.isNotEmpty)) {
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

  // UPDATED: Store keys in Firebase and show contact info
  Future<void> _generateKeys() async {
    setState(() {
      _isGeneratingKeys = true;
    });

    try {
      // Get or generate device ID
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = FirebaseService.generateDeviceId();
        await prefs.setString('device_id', deviceId);
      }

      // Generate keys
      final generatedKeys = FirebaseService.generateRegistrationKeys();
      
      // Store keys in Firebase
      final result = await FirebaseService.storePendingRegistration(
        registrationKeys: generatedKeys,
        deviceId: deviceId,
      );

      if (result['success']) {
        setState(() {
          _showContactInfo = true;
          // ADDED: Store key generation timestamp
          _keysGeneratedAt = DateTime.now();
          _keysExpireAt = DateTime.now().add(const Duration(days: 7));
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration keys generated successfully! Contact support to get your keys.'.tr()),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // UPDATED: Handle specific error cases - removed device registration blocking
        String errorMessage = result['message'] ?? 'Failed to generate keys';
        
        if (result['hasPendingKeys'] == true) {
          errorMessage = 'This device already has pending registration keys. Please use those keys or contact support.';
        }
        
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      debugPrint('Error generating keys: $e');
      _showErrorMessage('Failed to generate keys. Please check your internet connection and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingKeys = false;
        });
      }
    }
  }

  // REMOVED: _validateKeys() method (no longer needed as validation is done in Firebase)

  // UPDATED: Register company with user-entered keys
  Future<void> _registerCompany() async {
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
      // Get device ID
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = FirebaseService.generateDeviceId();
        await prefs.setString('device_id', deviceId);
      }

      // Get user entered keys
      final userEnteredKeys = _keyControllers.map((controller) => controller.text.trim()).toList();

      // Register with Firebase
      final result = await FirebaseService.registerCompany(
        customerName: _businessNameController.text.trim(),
        secondCustomerName: _secondBusinessNameController.text.trim(),
        customerAddress: _businessAddressController.text.trim(),
        customerPhone: _businessPhoneController.text.trim(),
        deviceId: deviceId,
        userEnteredKeys: userEnteredKeys, // Pass user entered keys for validation
      );

      if (result['success']) {
        // Save registration status locally
        await prefs.setBool('company_registered', true);
        await prefs.setBool('device_registered', true);
        await prefs.setString('company_id', result['companyId']);
        await prefs.setString('registration_mode', 'online');
        // Save business information to SharedPreferences
        await prefs.setString('business_name', _businessNameController.text.trim());
        await prefs.setString('second_business_name', _secondBusinessNameController.text.trim());
        await prefs.setString('business_address', _businessAddressController.text.trim());
        await prefs.setString('business_phone', _businessPhoneController.text.trim());
       
        // Update SettingsProvider directly to ensure immediate sync
        if (mounted) {
          final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
          await settingsProvider.saveAllSettings(
            businessName: _businessNameController.text.trim(),
            secondBusinessName: _secondBusinessNameController.text.trim(),
            businessAddress: _businessAddressController.text.trim(),
            businessPhone: _businessPhoneController.text.trim(),
          );
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration successful!'.tr()),
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
      } else {
        // UPDATED: Handle specific error cases for key reuse (removed device blocking)
        String errorMessage = result['message'] ?? 'Registration failed';
        
        if (result['keysAlreadyUsed'] == true) {
          errorMessage = 'These registration keys have already been used. Please contact support for new keys.';
        } else if (result['keysJustUsed'] == true) {
          errorMessage = 'These registration keys were just used. Please contact support for new keys.';
        } else if (result['isInvalidKeys'] == true) {
          errorMessage = 'Invalid registration keys. Please check and try again.';
        } else if (result['notFound'] == true) {
          errorMessage = 'No pending registration found. Please generate keys first.';
        } else if (result['isExpired'] == true) {
          errorMessage = 'Registration keys have expired. Please generate new ones.';
        }
        
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      debugPrint('Error registering company: $e');
      _showErrorMessage('Registration failed. Please check your internet connection and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ADDED: Helper method to format dates
  // String _formatDateTime(DateTime? dateTime) {
  //   if (dateTime == null) return '';
    
  //   final now = DateTime.now();
  //   final difference = dateTime.difference(now);
    
  //   if (difference.inDays > 0) {
  //     return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
  //   } else if (difference.inHours > 0) {
  //     return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
  //   } else if (difference.inMinutes > 0) {
  //     return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
  //   } else {
  //     return 'Soon';
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(55.0),
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
                            text: 'Online ',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          TextSpan(
                            text: 'Registration',
                            style: TextStyle(color: Colors.blue[700]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Register Your Company',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 85),
              
              // Generate Keys Section
              if (!_showContactInfo) ...[
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.vpn_key,
                        size: 64,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Generate Registration Keys'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click the button below to generate your unique registration keys',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isGeneratingKeys ? null : _generateKeys,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isGeneratingKeys
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Generate'.tr(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],

              // Contact Information and Registration Section
              if (_showContactInfo) ...[
                // Contact Information
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Contact for Keys'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Registration keys have been generated for your device. Please contact support to get your keys:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Phone contact
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _supportPhone,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Email contact
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _supportEmail,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time, color: Colors.orange[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Keys are valid for 7 days. Please complete registration within this time.',
                                    style: TextStyle(
                                      color: Colors.orange[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // ADDED: Show key generation and expiry information
                            if (_keysGeneratedAt != null || _keysExpireAt != null) ...[
                              // const SizedBox(height: 8),
                              // const Divider(height: 1),
                              // const SizedBox(height: 8),
                              if (_keysGeneratedAt != null) ...[
                                // Row(
                                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                //   children: [
                                //     Text(
                                //       'Generated:',
                                //       style: TextStyle(
                                //         color: Colors.orange[600],
                                //         fontSize: 11,
                                //         fontWeight: FontWeight.w500,
                                //       ),
                                //     ),
                                //     Text(
                                //       '${_keysGeneratedAt!.day}/${_keysGeneratedAt!.month}/${_keysGeneratedAt!.year} ${_keysGeneratedAt!.hour.toString().padLeft(2, '0')}:${_keysGeneratedAt!.minute.toString().padLeft(2, '0')}',
                                //       style: TextStyle(
                                //         color: Colors.orange[700],
                                //         fontSize: 11,
                                //         fontWeight: FontWeight.w600,
                                //       ),
                                //     ),
                                //   ],
                                // ),
                              ],
                              if (_keysExpireAt != null) ...[
                                // const SizedBox(height: 4),
                                // Row(
                                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                //   children: [
                                //     Text(
                                //       'Expires in:',
                                //       style: TextStyle(
                                //         color: Colors.orange[600],
                                //         fontSize: 11,
                                //         fontWeight: FontWeight.w500,
                                //       ),
                                //     ),
                                //     Text(
                                //       _formatDateTime(_keysExpireAt),
                                //       style: TextStyle(
                                //         color: Colors.orange[700],
                                //         fontSize: 11,
                                //         fontWeight: FontWeight.w600,
                                //       ),
                                //     ),
                                //   ],
                                // ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Registration Keys Input Section
                Text(
                  'Enter Your Registration Keys:'.tr(),
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
                            hintText: 'KEY ${index + 1}',
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
                  'Business Information:'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Warning message
                if (_showWarning) ...[
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
                  const SizedBox(height: 16),
                ],
                
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
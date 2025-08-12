import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _showGeneratedKeys = false;
  
  // The generated keys that user needs to match
  List<String> _generatedKeys = [];

  @override
  void initState() {
    super.initState();

    // Add listeners to business info fields to show warning
    _businessNameController.addListener(_onBusinessInfoChanged);
    _secondBusinessNameController.addListener(_onBusinessInfoChanged);
    _businessAddressController.addListener(_onBusinessInfoChanged);
    _businessPhoneController.addListener(_onBusinessInfoChanged);
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

  void _generateKeys() {
    setState(() {
      _generatedKeys = FirebaseService.generateRegistrationKeys();
      _showGeneratedKeys = true;
    });
  }

  bool _validateKeys() {
    final userKeys = _keyControllers.map((controller) => controller.text.trim()).toList();
    return FirebaseService.validateRegistrationKeys(_generatedKeys, userKeys);
  }

  Future<void> _registerCompany() async {
    // Validate that keys are generated
    if (_generatedKeys.isEmpty) {
      _showErrorMessage('Please generate registration keys first');
      return;
    }

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
        _showErrorMessage('Registration keys do not match. Please check and try again.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get or generate device ID
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = FirebaseService.generateDeviceId();
        await prefs.setString('device_id', deviceId);
      }

      // Register with Firebase
      final result = await FirebaseService.registerCompany(
        registrationKeys: _generatedKeys,
        customerName: _businessNameController.text.trim(),
        secondCustomerName: _secondBusinessNameController.text.trim(),
        customerAddress: _businessAddressController.text.trim(),
        customerPhone: _businessPhoneController.text.trim(),
        deviceId: deviceId,
      );

      if (result['success']) {
        // Save registration status locally
        await prefs.setBool('company_registered', true);
        await prefs.setBool('device_registered', true);
        await prefs.setString('company_id', result['companyId']);
        await prefs.setString('registration_mode', 'online');
        // FIXED: Save business information to SharedPreferences so SettingsProvider can load it
        await prefs.setString('business_name', _businessNameController.text.trim());
        await prefs.setString('second_business_name', _secondBusinessNameController.text.trim());
        await prefs.setString('business_address', _businessAddressController.text.trim());
        await prefs.setString('business_phone', _businessPhoneController.text.trim());
       
        // ADDED: Update SettingsProvider directly to ensure immediate sync
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
        _showErrorMessage(result['message'] ?? 'Registration failed');
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
        // title: Text('Register Your Company'.tr()),
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
              if (!_showGeneratedKeys) ...[
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
                        onPressed: _generateKeys,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
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

              // Generated Keys Display and Input Section
              if (_showGeneratedKeys) ...[
               // Display Generated Keys
                // Container(
                //   padding: const EdgeInsets.all(16),
                //   decoration: BoxDecoration(
                //     color: Colors.green[50],
                //     borderRadius: BorderRadius.circular(12),
                //     border: Border.all(color: Colors.green[200]!),
                //   ),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Row(
                //         children: [
                //           Icon(Icons.key, color: Colors.green[700]),
                //           const SizedBox(width: 8),
                //           Text(
                //             'Your Registration Keys:'.tr(),
                //             style: TextStyle(
                //               fontSize: 16,
                //               fontWeight: FontWeight.bold,
                //               color: Colors.green[700],
                //             ),
                //           ),
                //         ],
                //       ),
                //       const SizedBox(height: 12),
                //       Row(
                //         children: _generatedKeys.asMap().entries.map((entry) {
                //           return Expanded(
                //             child: Padding(
                //               padding: EdgeInsets.only(
                //                 right: entry.key < 4 ? 8.0 : 0,
                //               ),
                //               child: Container(
                //                 padding: const EdgeInsets.symmetric(vertical: 12),
                //                 decoration: BoxDecoration(
                //                   color: Colors.white,
                //                   borderRadius: BorderRadius.circular(8),
                //                   border: Border.all(color: Colors.green[300]!),
                //                 ),
                //                 child: Text(
                //                   entry.value,
                //                   textAlign: TextAlign.center,
                //                   style: TextStyle(
                //                     fontSize: 12,
                //                     fontWeight: FontWeight.bold,
                //                     color: Colors.green[700],
                //                     letterSpacing: 1,
                //                   ),
                //                 ),
                //               ),
                //             ),
                //           );
                //         }).toList(),
                //       ),
                //     ],
                //   ),
                // ),
                
                const SizedBox(height: 24),
                
                // Registration Keys Input Section
                Text(
                  'Enter the Registration Keys Above:'.tr(),
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
                            // hintText: 'KEY ${index + 1}',
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
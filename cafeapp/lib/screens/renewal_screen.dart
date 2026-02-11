import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localization.dart';
import '../services/firebase_service.dart';
import '../services/demo_service.dart';
import '../services/license_service.dart';
import 'dashboard_screen.dart';
import '../utils/keyboard_utils.dart';

enum RenewalType { demo, license }

class RenewalScreen extends StatefulWidget {
  final RenewalType renewalType;
  
  const RenewalScreen({
    super.key, 
    required this.renewalType,
  });

  @override
  State<RenewalScreen> createState() => _RenewalScreenState();
}

class _RenewalScreenState extends State<RenewalScreen> {
  // Renewal key controllers
  final List<TextEditingController> _keyControllers = List.generate(5, (index) => TextEditingController());
  final List<FocusNode> _keyFocusNodes = List.generate(5, (index) => FocusNode());
  
  bool _isLoading = false;
  bool _showContactInfo = false;
  bool _isGeneratingKeys = false;
  
  final String _supportPhone1 = "+968 7184 0022";
  final String _supportPhone2 = "+968 9906 2181";
  final String _supportPhone3 = "+968 7989 5704";
  final String _supportEmail = "AI@simsai.tech";

  @override
  void initState() {
    super.initState();
    _checkExistingPendingKeys();
  }

  // Check if device already has pending renewal keys
  Future<void> _checkExistingPendingKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = FirebaseService.generateDeviceId();
        await prefs.setString('device_id', deviceId);
        return;
      }

      final result = await FirebaseService.getPendingRenewal(deviceId, widget.renewalType);
      
      if (result['success']) {
        setState(() {
          _showContactInfo = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You already have pending renewal keys. Please use those keys to complete renewal.'.tr()),
              backgroundColor: Colors.grey[600],
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (result['isExpired'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your previous renewal keys have expired. You can generate new ones.'.tr()),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking existing pending renewal keys: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _keyControllers) {
      controller.dispose();
    }
    for (var focusNode in _keyFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onKeyChanged(int index, String value) {
    if (value.length >= 6 && index < 4) {
      _keyFocusNodes[index + 1].requestFocus();
    }
    
    if (value.isEmpty && index > 0) {
      _keyFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _generateRenewalKeys() async {
    setState(() {
      _isGeneratingKeys = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = FirebaseService.generateDeviceId();
        await prefs.setString('device_id', deviceId);
      }
        // NEW: Get business name from saved preferences
      String? businessName = prefs.getString('business_name');
      String? businessEmail = prefs.getString('business_email');

      if (businessName == null || businessName.isEmpty ) {
        businessName = widget.renewalType == RenewalType.demo 
            ? '' 
            : '';
      }
      if (businessEmail == null || businessEmail.isEmpty) {
        businessEmail = widget.renewalType == RenewalType.demo
            ? ''
            : '';
      }
      final generatedKeys = FirebaseService.generateRegistrationKeys();
      
      final result = await FirebaseService.storePendingRenewal(
        renewalKeys: generatedKeys,
        deviceId: deviceId,
        renewalType: widget.renewalType,
        businessName: businessName, // Pass business name
        businessEmail: businessEmail, // Pass business email

      );

      if (result['success']) {
        setState(() {
          _showContactInfo = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Renewal keys generated successfully! Contact support to get your keys.'.tr()),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        String errorMessage = result['message'] ?? 'Failed to generate renewal keys';
        
        if (result['hasPendingKeys'] == true) {
          errorMessage = 'This device already has pending renewal keys. Please use those keys or contact support.';
        }
        
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      debugPrint('Error generating renewal keys: $e');
      _showErrorMessage('Failed to generate keys. Please check your internet connection and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingKeys = false;
        });
      }
    }
  }

  Future<void> _processRenewal() async {
    // Validate that all key fields are filled
    for (int i = 0; i < 5; i++) {
      if (_keyControllers[i].text.trim().isEmpty) {
        _showErrorMessage('Please fill all renewal key fields');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null) {
        deviceId = FirebaseService.generateDeviceId();
        await prefs.setString('device_id', deviceId);
      }

      final userEnteredKeys = _keyControllers.map((controller) => controller.text.trim()).toList();

      final result = await FirebaseService.processRenewal(
        deviceId: deviceId,
        userEnteredKeys: userEnteredKeys,
        renewalType: widget.renewalType,
      );

      if (result['success']) {
        // Update local services based on renewal type
        if (widget.renewalType == RenewalType.demo) {
          await DemoService.upgradeDemoToLicense();
        } else {
          await LicenseService.renewLicense();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Renewal successful!'.tr()),
              backgroundColor: Colors.green,
            ),
          );

          await Future.delayed(const Duration(seconds: 1));
          
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
              (route) => false,
            );
          }
        }
      } else {
        String errorMessage = result['message'] ?? 'Renewal failed';
        
        if (result['keysAlreadyUsed'] == true) {
          errorMessage = 'These renewal keys have already been used. Please contact support for new keys.';
        } else if (result['keysJustUsed'] == true) {
          errorMessage = 'These renewal keys were just used. Please contact support for new keys.';
        } else if (result['isInvalidKeys'] == true) {
          errorMessage = 'Invalid renewal keys. Please check and try again.';
        } else if (result['notFound'] == true) {
          errorMessage = 'No pending renewal found. Please generate keys first.';
        } else if (result['isExpired'] == true) {
          errorMessage = 'Renewal keys have expired. Please generate new ones.';
        }
        
        _showErrorMessage(errorMessage);
      }
    } catch (e) {
      debugPrint('Error processing renewal: $e');
      _showErrorMessage('Renewal failed. Please check your internet connection and try again.');
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

  String _getRenewalTypeTitle() {
    return widget.renewalType == RenewalType.demo 
        ? '' 
        : '';
  }

  String _getRenewalTypeDescription() {
    return widget.renewalType == RenewalType.demo 
        ? 'Upgrade Plan'
        : 'Renew your license for another year';
  }

  MaterialColor _getRenewalTypeColor() {
    return widget.renewalType == RenewalType.demo 
        ? Colors.blue 
        : Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final renewalColor = _getRenewalTypeColor();
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: renewalColor.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_getRenewalTypeTitle()),
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
                    Icon(
                      widget.renewalType == RenewalType.demo 
                          ? Icons.schedule 
                          : Icons.verified,
                      size: 64,
                      color: renewalColor.shade700,
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: widget.renewalType == RenewalType.demo ? 'Demo ' : 'License ',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          TextSpan(
                            text: 'Renewal',
                            style: TextStyle(color: renewalColor.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getRenewalTypeDescription(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 50),
              
              // Generate Keys Section or Key Entry Section
              if (!_showContactInfo) ...[
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Generate Renewal Keys'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click the button below to generate your unique renewal keys',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isGeneratingKeys ? null : _generateRenewalKeys,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: renewalColor.shade700,
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

              // Contact Information and Key Entry Section
              if (_showContactInfo) ...[
                // Contact Information
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: renewalColor.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: renewalColor.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: renewalColor.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Contact for Keys'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: renewalColor.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Renewal keys have been generated for your device. Please contact support to get your keys:',
                        style: TextStyle(
                          fontSize: 14,
                          color: renewalColor.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Phone contacts
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone, color: renewalColor.shade700, size: 20),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _supportPhone1,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: renewalColor.shade700,
                                ),
                              ),
                              Text(
                                _supportPhone2,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: renewalColor.shade700,
                                ),
                              ),
                              Text(
                                _supportPhone3,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: renewalColor.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Email contact
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email, color: renewalColor.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _supportEmail,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: renewalColor.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Keys are valid for 7 days. Please complete renewal within this time.',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Renewal Keys Input Section
                Text(
                  'Enter Your Renewal Keys:'.tr(),
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
                        child: DoubleTapKeyboardListener(
                          focusNode: _keyFocusNodes[index],
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
                                borderSide: BorderSide(color: renewalColor.shade700, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 40),
                
                // Renew Button
                Center(
                  child: SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _processRenewal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: renewalColor.shade700,
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
                              'Renew'.tr(),
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
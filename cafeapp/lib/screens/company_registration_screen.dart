import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localization.dart';
import 'dashboard_screen.dart';

class CompanyRegistrationScreen extends StatefulWidget {
  const CompanyRegistrationScreen({super.key});

  @override
  State<CompanyRegistrationScreen> createState() => _CompanyRegistrationScreenState();
}

class _CompanyRegistrationScreenState extends State<CompanyRegistrationScreen> {
  // Registration key controllers
  final List<TextEditingController> _keyControllers = List.generate(5, (index) => TextEditingController());
  final List<FocusNode> _keyFocusNodes = List.generate(5, (index) => FocusNode());
  
  // Customer information controllers
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  
  // Focus nodes for customer info
  final FocusNode _customerNameFocus = FocusNode();
  final FocusNode _customerAddressFocus = FocusNode();
  final FocusNode _customerPhoneFocus = FocusNode();
  
  bool _isLoading = false;
  bool _showWarning = false;
  
  // The correct keys
  final List<String> _correctKeys = ['M2P016', 'A2L018', 'A2Z023', 'B2CAFE', 'M1U985'];

  @override
  void initState() {
    super.initState();
    
     // Add listeners to customer info fields to show warning
    _customerNameController.addListener(_onCustomerInfoChanged);
    _customerAddressController.addListener(_onCustomerInfoChanged);
    _customerPhoneController.addListener(_onCustomerInfoChanged);
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
    
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerPhoneController.dispose();
    
    _customerNameFocus.dispose();
    _customerAddressFocus.dispose();
    _customerPhoneFocus.dispose();
    
    super.dispose();
  }

  void _onCustomerInfoChanged() {
    if (!_showWarning && (_customerNameController.text.isNotEmpty || 
        _customerAddressController.text.isNotEmpty || 
        _customerPhoneController.text.isNotEmpty)) {
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

      // Save company registration
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('company_registered', true);
      // Mark device as fully registered only after company registration
      await prefs.setBool('device_registered', true);
      await prefs.setString('customer_name', _customerNameController.text.trim());
      await prefs.setString('customer_address', _customerAddressController.text.trim());
      await prefs.setString('customer_phone', _customerPhoneController.text.trim());

      // // Also update settings provider with customer information
      // if (mounted) {
      //   final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      //   await settingsProvider.setSetting('business_name', _customerNameController.text.trim());
      //   await settingsProvider.setSetting('business_address', _customerAddressController.text.trim());
      //   await settingsProvider.setSetting('business_phone', _customerPhoneController.text.trim());
      // }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration successfull'.tr()),
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
                      '',
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
                          'Warning: Once you register, you won\'t be able to edit your buisness information again.'.tr(),
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
                controller: _customerNameController,
                focusNode: _customerNameFocus,
                decoration: InputDecoration(
                  labelText: 'Name'.tr(),
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
              
              // Business Address
              TextField(
                controller: _customerAddressController,
                focusNode: _customerAddressFocus,
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
                controller: _customerPhoneController,
                focusNode: _customerPhoneFocus,
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
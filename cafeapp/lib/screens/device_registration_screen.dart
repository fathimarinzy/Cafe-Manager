import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localization.dart';
import 'company_registration_screen.dart';
import 'online_company_registration_screen.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({super.key});

  @override
  State<DeviceRegistrationScreen> createState() => _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  bool _isOnlineSelected = false;
  bool _isOfflineSelected = false;
  bool _isOfflineEnabled = false;
  bool _isNextButtonEnabled = false;
  final TextEditingController _hiddenController = TextEditingController();
  final FocusNode _hiddenFocusNode = FocusNode();
  String _enteredCode = '';

  @override
  void dispose() {
    _hiddenController.dispose();
    _hiddenFocusNode.dispose();
    super.dispose();
  }

  void _onOnlineCheckboxChanged(bool? value) {
    setState(() {
      _isOnlineSelected = value ?? false;
      if (_isOnlineSelected) {
        _isOfflineSelected = false;
        _enteredCode = '';
        _hiddenController.clear();
        // Show keyboard by focusing the hidden input
        Future.delayed(const Duration(milliseconds: 100), () {
          _hiddenFocusNode.requestFocus();
        });
      } else {
        _hiddenFocusNode.unfocus();
        _hiddenController.clear();
        _enteredCode = '';
        _isOfflineEnabled = false;
      }
      _updateNextButtonState();
    });
  }

  void _onOfflineCheckboxChanged(bool? value) {
    if (_isOfflineEnabled) {
      setState(() {
        _isOfflineSelected = value ?? false;
        if (_isOfflineSelected) {
          _isOnlineSelected = false;
          _hiddenFocusNode.unfocus();
          _hiddenController.clear();
          _enteredCode = '';
        }
        _updateNextButtonState();
      });
    }
  }

  void _onCodeChanged(String value) {
    setState(() {
      _enteredCode = value;
      if (value == "0000") {
        _isOfflineEnabled = true;
        // Hide keyboard and show success feedback
        _hiddenFocusNode.unfocus();
      } else {
        _isOfflineEnabled = false;
        _isOfflineSelected = false;
      }
      _updateNextButtonState();
    });
  }

  void _updateNextButtonState() {
    setState(() {
      _isNextButtonEnabled = _isOnlineSelected || _isOfflineSelected;
    });
  }

  Future<void> _onNextPressed() async {
    if (!_isNextButtonEnabled) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save the selected mode
      if (_isOnlineSelected) {
        // Save online mode but don't mark device as fully registered yet
        await prefs.setString('device_mode', 'online');
        await prefs.setBool('offline_unlocked', _enteredCode == "0000");
        
        // Navigate to online company registration screen
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const OnlineCompanyRegistrationScreen()),
          );
        }
      } else if (_isOfflineSelected) {
        // Don't mark device as fully registered yet for offline mode
        // Only save the mode and offline unlock status
        await prefs.setString('device_mode', 'offline');
        await prefs.setBool('offline_unlocked', true);
        
        // Navigate to offline company registration screen
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CompanyRegistrationScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving registration: $e');
      // Show error message if needed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed. Please try again.'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Header section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 34.0),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                
                                // Header
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'SIMS ', 
                                        style: TextStyle(
                                          color: Colors.blue[900],
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'AI',
                                        style: TextStyle(
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Device Registration',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Centered registration options
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Container(
                                  width: double.infinity,
                                  constraints: const BoxConstraints(maxWidth: 400),
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey[300]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withAlpha(25),
                                        spreadRadius: 2,
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Register your device :'.tr(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      
                                      const SizedBox(height: 30),
                                      
                                      // Online option
                                      Container(
                                        decoration: BoxDecoration(
                                          color: _isOnlineSelected ? Colors.blue[50] : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _isOnlineSelected ? Colors.blue[300]! : Colors.grey[300]!,
                                            width: _isOnlineSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () => _onOnlineCheckboxChanged(!_isOnlineSelected),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: _isOnlineSelected,
                                                  onChanged: _onOnlineCheckboxChanged,
                                                  activeColor: Colors.blue[700],
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Online'.tr(),
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      if (_isOnlineSelected) ...[
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          'Cloud-based registration with Firebase',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.blue[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      // Offline option
                                      Container(
                                        decoration: BoxDecoration(
                                          color: _isOfflineSelected 
                                              ? Colors.blue[50] 
                                              : _isOfflineEnabled 
                                                  ? Colors.white 
                                                  : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _isOfflineSelected 
                                                ? Colors.blue[300]! 
                                                : _isOfflineEnabled 
                                                    ? Colors.grey[300]! 
                                                    : Colors.grey[200]!,
                                            width: _isOfflineSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: _isOfflineEnabled 
                                              ? () => _onOfflineCheckboxChanged(!_isOfflineSelected)
                                              : null,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: _isOfflineSelected,
                                                  onChanged: _isOfflineEnabled ? _onOfflineCheckboxChanged : null,
                                                  activeColor: Colors.blue[700],
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Offline'.tr(),
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                          color: _isOfflineEnabled ? Colors.black87 : Colors.grey[400],
                                                        ),
                                                      ),
                                                      if (!_isOfflineEnabled) ...[
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          'Requires special unlock code',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey[500],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      SizedBox(
                                        width: 200,
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: _isNextButtonEnabled ? _onNextPressed : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _isNextButtonEnabled ? Colors.blue[700] : Colors.grey[300],
                                            foregroundColor: Colors.white,
                                            elevation: _isNextButtonEnabled ? 2 : 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            'Next'.tr(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: _isNextButtonEnabled ? Colors.white : Colors.grey[500],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Hidden input field positioned off-screen
          Positioned(
            left: -1000,
            top: -1000,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _hiddenController,
                focusNode: _hiddenFocusNode,
                onChanged: _onCodeChanged,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
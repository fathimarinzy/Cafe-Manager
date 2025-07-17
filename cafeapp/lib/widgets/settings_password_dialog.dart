import 'package:flutter/material.dart';
import '../services/settings_password_service.dart';
import '../screens/settings_screen.dart';
import '../utils/app_localization.dart';

class SettingsPasswordDialog extends StatefulWidget {
  const SettingsPasswordDialog({super.key});

  @override
  State<SettingsPasswordDialog> createState() => _SettingsPasswordDialogState();
}

class _SettingsPasswordDialogState extends State<SettingsPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final SettingsPasswordService _passwordService = SettingsPasswordService();
  bool _isLoading = false;
  bool _isError = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _passwordService.initializeDefaultPasswords();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    String password = _passwordController.text.trim();
    
    if (password.isEmpty) {
      setState(() {
        _isError = true;
        _errorMessage = 'Please enter a password'.tr();
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = '';
    });
    
    try {
      final userType = await _passwordService.verifyPassword(password);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (userType != null) {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SettingsScreen(
                userType: userType,
              ),
            ),
          );
        } else {
          setState(() {
            _isError = true;
            _errorMessage = 'Invalid password'.tr();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'Error verifying password'.tr();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: contentBox(context),
    );
  }

  Widget contentBox(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 800 ? screenWidth * 0.9 : 500.0;
  
    return Container(
      width: dialogWidth,
      height: 270,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10.0,
            offset: Offset(0.0, 10.0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Enter Password'.tr(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 15),
          // Text(
          //   'Please enter the password to access settings'.tr(),
          //   style: const TextStyle(
          //     fontSize: 14,
          //   ),
          //   textAlign: TextAlign.center,
          // ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              labelText: 'Password'.tr(),
              errorText: _isError ? _errorMessage : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            onSubmitted: (_) => _verifyPassword(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
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
                    : Text('Verify'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
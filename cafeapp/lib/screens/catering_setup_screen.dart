
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'menu_screen.dart';
import '../providers/order_provider.dart';
import 'order_list_screen.dart' as import_order_list;
import '../models/person.dart';
import 'search_person_screen.dart';
import '../utils/app_localization.dart';
import '../utils/keyboard_utils.dart';

class CateringSetupScreen extends StatefulWidget {
  const CateringSetupScreen({super.key});

  @override
  State<CateringSetupScreen> createState() => _CateringSetupScreenState();
}

class _CateringSetupScreenState extends State<CateringSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventDateController = TextEditingController();
  final _eventTimeController = TextEditingController();
  final _guestsController = TextEditingController();
  final _addressController = TextEditingController();
  final _tokenController = TextEditingController(); // Token number controller
  final _guestsFocusNode = FocusNode();
  final _tokenFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  Person? _selectedPerson; // Selected customer
  
  String _selectedEventType = 'Wedding';
  final List<String> _eventTypes = ['Wedding', 'Birthday', 'Corporate', 'Anniversary', 'Other'];

  @override
  void dispose() {
    _eventDateController.dispose();
    _eventTimeController.dispose();
    _guestsController.dispose();
    _addressController.dispose();
    _tokenController.dispose();
    _guestsFocusNode.dispose();
    _tokenFocusNode.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _eventDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _eventTimeController.text = picked.format(context);
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // 1. Save details to OrderProvider
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      
      orderProvider.setCurrentServiceType('Catering - $_selectedEventType');
      
      orderProvider.setCateringDetails(
        date: _eventDateController.text,
        time: _eventTimeController.text,
        guests: int.tryParse(_guestsController.text),
        type: _selectedEventType,
      );
      
      // Also set delivery address
      orderProvider.setDeliveryDetails(
        address: _addressController.text,
      );
      
      // Set Token Number
      orderProvider.setCateringTokenNumber(_tokenController.text);
      
      // Set Selected Person
      orderProvider.setSelectedPerson(_selectedPerson);

      // 2. Navigate to MenuScreen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => MenuScreen(
            serviceType: 'Catering - $_selectedEventType',
            serviceColor: const Color(0xFFFFD700), // Gold
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark background
      appBar: AppBar(
        title: Text('Catering Event Setup'.tr()),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Catering Orders'.tr(),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const import_order_list.OrderListScreen(isCateringOnly: true),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cake,
                    size: 60,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Event Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedEventType,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Event Type'.tr(), Icons.event),
                items: _eventTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type.tr()),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedEventType = newValue!;
                  });
                },
              ),
              const SizedBox(height: 20),
              
              // Date & Time Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _eventDateController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Date'.tr(), Icons.calendar_today),
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (value) => value!.isEmpty ? 'Select Date'.tr() : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _eventTimeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Time'.tr(), Icons.access_time),
                      readOnly: true,
                      onTap: () => _selectTime(context),
                      validator: (value) => value!.isEmpty ? 'Select Time'.tr() : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Guest Count
              DoubleTapKeyboardListener(
                focusNode: _guestsFocusNode,
                child: TextFormField(
                  controller: _guestsController,
                  focusNode: _guestsFocusNode,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Number of Guests'.tr(), Icons.people),
                  validator: (value) => value!.isEmpty ? 'Enter guest count'.tr() : null,
                ),
              ),
              const SizedBox(height: 20),
              
              // Token Number
              DoubleTapKeyboardListener(
                focusNode: _tokenFocusNode,
                child: TextFormField(
                  controller: _tokenController,
                  focusNode: _tokenFocusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Token Number'.tr(), Icons.confirmation_number),
                  validator: (value) => value!.isEmpty ? 'Enter token number'.tr() : null,
                ),
              ),
              const SizedBox(height: 20),
              
              // Customer Selection
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer (Optional)'.tr(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.white.withAlpha(179)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedPerson?.name ?? 'Select Customer'.tr(),
                            style: TextStyle(
                              color: _selectedPerson != null ? Colors.white : Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_selectedPerson != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _selectedPerson = null;
                              });
                            },
                          ),
                        ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SearchPersonScreen(),
                              ),
                            );
                            if (result != null && result is Person) {
                              setState(() {
                                _selectedPerson = result;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C2C2C),
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Select'.tr()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Venue Address
              DoubleTapKeyboardListener(
                focusNode: _addressFocusNode,
                child: TextFormField(
                  controller: _addressController,
                  focusNode: _addressFocusNode,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: _buildInputDecoration('Venue Address'.tr(), Icons.location_on),
                  validator: (value) => value!.isEmpty ? 'Enter venue address'.tr() : null,
                ),
              ),
              const SizedBox(height: 40),
              
              // Submit Button
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:  Text(
                  'Continue to Menu'.tr(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: const Color(0xFFFFD700)),
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1),
      ),
    );
  }
}

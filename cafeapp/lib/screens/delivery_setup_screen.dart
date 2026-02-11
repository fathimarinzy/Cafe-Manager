import 'package:flutter/material.dart';

import 'dart:async'; // For Timer
import 'package:provider/provider.dart';
import 'package:cafeapp/utils/app_localization.dart';
import '../providers/order_provider.dart';
import '../providers/person_provider.dart';
import '../models/person.dart';
// import '../models/delivery_boy.dart';
import '../providers/delivery_boy_provider.dart';
// import '../providers/person_provider.dart';
import 'menu_screen.dart';
import 'person_form_screen.dart';
import '../utils/keyboard_utils.dart';

class DeliverySetupScreen extends StatefulWidget {
  const DeliverySetupScreen({super.key});

  @override
  State<DeliverySetupScreen> createState() => _DeliverySetupScreenState();
}

class _DeliverySetupScreenState extends State<DeliverySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _addressController = TextEditingController();
  final _deliveryBoyController = TextEditingController();
  final _chargeController = TextEditingController();
  final _searchController = TextEditingController();

  Person? _selectedCustomer;
  // bool _isSearching = false; // Removed in favor of Overlay
  bool _useCustomerAddress = false;
  Timer? _debounce; // Timer for search debounce
  
  // Overlay controls
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();
  final FocusNode _chargeFocusNode = FocusNode();


  @override
  void initState() {
    super.initState();
    // Pre-load persons
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PersonProvider>(context, listen: false).loadPersons();
      Provider.of<DeliveryBoyProvider>(context, listen: false).loadDeliveryBoys();
      
      // Load existing delivery details from provider if any (for editing case)
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (orderProvider.deliveryAddress != null) {
        _addressController.text = orderProvider.deliveryAddress!;
      }
      if (orderProvider.deliveryBoy != null) {
        _deliveryBoyController.text = orderProvider.deliveryBoy!;
      }
      if (orderProvider.deliveryCharge != null) {
        _chargeController.text = orderProvider.deliveryCharge.toString();
      }
      if (orderProvider.selectedPerson != null) {
        setState(() {
          _selectedCustomer = orderProvider.selectedPerson;
          // Also set address if empty
          if (_addressController.text.isEmpty && _selectedCustomer!.place.isNotEmpty) {
            _addressController.text = _selectedCustomer!.place;
          }
        });
      }
    });

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _showOverlay();
      } else {
        // Delay hiding to allow tap on overlay items
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!_searchFocusNode.hasFocus) {
             _hideOverlay();
          }
        });
      }
    });
  }

  void _onCustomerSelected(Person person) {
    _debounce?.cancel();
    if (!mounted) return;
    
    setState(() {
      _selectedCustomer = person;
      _searchController.clear();
      
      // Auto-fill address from customer location if address field is empty or user wants
      if (_useCustomerAddress || _addressController.text.trim().isEmpty) {
          _addressController.text = person.place;
          _useCustomerAddress = true; // Auto-select checkbox
      }
    });

    // Update Person Provider search 
    Provider.of<PersonProvider>(context, listen: false).clearSearch();
    _hideOverlay();
    _searchFocusNode.unfocus();
  }

  void _addNewCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PersonFormScreen()),
    );
    
    if (result == true && mounted) {
      // Reload persons
      Provider.of<PersonProvider>(context, listen: false).loadPersons();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer added successfully'.tr())),
      );
    }
  }

  void _startOrder() {
    if (_formKey.currentState!.validate()) {
      if (_selectedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Please select a customer'.tr()), backgroundColor: Colors.red),
        );
        return;
      }

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      
      // Set Delivery Details in Provider
      orderProvider.setSelectedPerson(_selectedCustomer);
      orderProvider.setDeliveryDetails(
        address: _addressController.text,
        boy: _deliveryBoyController.text,
        charge: double.tryParse(_chargeController.text) ?? 0.0,
      );
      
      // Set Service Type
      orderProvider.setCurrentServiceType('Delivery');
      
      // Navigate to Menu
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MenuScreen(serviceType: 'Delivery', serviceColor: Colors.blue),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addressController.dispose();
    _deliveryBoyController.dispose();
    _chargeController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _addressFocusNode.dispose();
    _chargeFocusNode.dispose();
    _hideOverlay();
    super.dispose();
  }

  // Overlay Methods
  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _hideOverlay();
    } else {
      _searchFocusNode.requestFocus();
      _showOverlay();
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);


    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _layerLink.leaderSize?.width ?? 300, 
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 50.0), // Dropdown offset
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Consumer<PersonProvider>(
                builder: (context, personProvider, child) {
                  // If query is empty, show all. If not, show results.
                  final List<Person> displayList = _searchController.text.isEmpty 
                      ? personProvider.persons 
                      : personProvider.searchResults;

                  if (displayList.isEmpty) {
                    if (_searchController.text.isNotEmpty && personProvider.persons.isNotEmpty) {
                       return Padding(
                         padding: const EdgeInsets.all(16.0),
                         child: Text('No matching customers found'.tr(), style: TextStyle(color: Colors.grey[600])),
                       );
                    }
                    if (personProvider.persons.isEmpty) {
                         return Padding(
                         padding: const EdgeInsets.all(16.0),
                         child: Text('No customers yet. Add one!'.tr(), style: TextStyle(color: Colors.grey[600])),
                       );
                    }
                  }

                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: displayList.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final person = displayList[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          foregroundColor: Colors.blue[800],
                          child: Text(person.name.isNotEmpty ? person.name[0].toUpperCase() : '?'),
                        ),
                        title: Text(person.name),
                        subtitle: Text('${person.phoneNumber} • ${person.place}'),
                        onTap: () => _onCustomerSelected(person),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  // Update search when typing
  void _onSearchChanged(String val, PersonProvider provider) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      
      _debounce = Timer(const Duration(milliseconds: 100), () { // Faster debounce for local filtering if needed
        if (!mounted) return;
        if (val.isEmpty) {
           // If empty, we just refresh the overlay to show all (handled by builder)
           _overlayEntry?.markNeedsBuild();
        } else {
           provider.searchPersons(val);
           _overlayEntry?.markNeedsBuild();
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Delivery Setup'.tr()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: RepaintBoundary( // OPTIMIZATION: Cache rendering
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(), // OPTIMIZATION: Prevent bounce/jank
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Customer Selection Section
                      _buildSectionTitle('Customer'.tr(), Icons.person),
                      const SizedBox(height: 16),
                      
                      if (_selectedCustomer != null)
                        _buildSelectedCustomerCard()
                      else
                        _buildCustomerSearch(),
                        
                      const SizedBox(height: 32),
                      
                      // 2. Delivery Details Section
                      // 2. Delivery Details Section
                      _buildSectionTitle('Delivery Information'.tr(), Icons.local_shipping),
                      
                      if (_selectedCustomer != null)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Same as above'.tr(), style: TextStyle(color: Colors.grey[700])),
                          value: _useCustomerAddress,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: Colors.blue,
                          onChanged: (val) {
                            setState(() {
                              _useCustomerAddress = val ?? false;
                              if (_useCustomerAddress && _selectedCustomer != null) {
                                _addressController.text = _selectedCustomer!.place;
                              }
                            });
                          },
                        ),
  
                      const SizedBox(height: 16),
                      
                      // Address Field
                      DoubleTapKeyboardListener(
                        focusNode: _addressFocusNode,
                        child: TextFormField(
                          controller: _addressController,
                          focusNode: _addressFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Delivery Address'.tr(),
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLines: 2,
                          validator: (value) => value!.isEmpty ? 'Please enter address'.tr() : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          // Delivery Boy Field
                          Expanded(
                            flex: 2,
                            child: Consumer<DeliveryBoyProvider>(
                              builder: (context, dbProvider, child) {
                                // If no delivery boys, show text field as fallback? 
                                // Or better: Show Dropdown with "Add new" option or just valid options.
                                
                                final deliveryBoys = dbProvider.deliveryBoys;
                                
                                return DropdownButtonFormField<String>(
                                  value: _deliveryBoyController.text.isNotEmpty && 
                                         deliveryBoys.any((b) => b.name == _deliveryBoyController.text) 
                                         ? _deliveryBoyController.text 
                                         : null,
                                  decoration: InputDecoration(
                                    labelText: 'Delivery Boy'.tr(),
                                    prefixIcon: const Icon(Icons.directions_bike),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  items: deliveryBoys.map((boy) {
                                    return DropdownMenuItem(
                                      value: boy.name,
                                      child: Text(boy.name),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      _deliveryBoyController.text = val;
                                    }
                                  },
                                  validator: (value) => value == null && _deliveryBoyController.text.isEmpty ? 'Select delivery boy'.tr() : null,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Delivery Charge Field
                          Expanded(
                            flex: 1,
                            child: DoubleTapKeyboardListener(
                              focusNode: _chargeFocusNode,
                              child: TextFormField(
                                controller: _chargeController,
                                focusNode: _chargeFocusNode,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Charge'.tr(),
                                  prefixIcon: const Icon(Icons.attach_money),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                   if (value != null && value.isNotEmpty) {
                                     if (double.tryParse(value) == null) return 'Invalid'.tr();
                                   }
                                   return null;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)), // OPTIMIZATION: Use simple border instead of heavy shadow
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: Text(
                    'Start Order'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue[800], size: 28),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSelectedCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[200],
            child: Text(
              _selectedCustomer!.name[0].toUpperCase(),
              style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCustomer!.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _selectedCustomer!.phoneNumber,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              setState(() {
                _selectedCustomer = null;
                _addressController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSearch() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Consumer<PersonProvider>(
                builder: (context, personProvider, child) {
                    return CompositedTransformTarget(
                      link: _layerLink,
                      child: DoubleTapKeyboardListener(
                        focusNode: _searchFocusNode,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Select or Search Customer...'.tr(),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_drop_down),
                              onPressed: _toggleOverlay,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (val) => _onSearchChanged(val, personProvider),
                          onTap: () {
                             // Ensure overlay shows on tap
                             _showOverlay();
                          },
                        ),
                      ),
                    );
                },
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _addNewCustomer,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Icon(Icons.person_add, color: Colors.blue),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
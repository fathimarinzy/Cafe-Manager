import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../providers/person_provider.dart';
import '../utils/app_localization.dart';
import '../utils/keyboard_utils.dart';

class PersonFormScreen extends StatefulWidget {
  final Person? person;
  const PersonFormScreen({super.key, this.person});

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String phoneNumber = '';
  String place = '';
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _placeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.person != null) {
      name = widget.person!.name;
      phoneNumber = widget.person!.phoneNumber;
      place = widget.person!.place;
    }
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _placeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final personProvider = Provider.of<PersonProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person != null ? 'Edit Customer Details'.tr() : 'Customer Details'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DoubleTapKeyboardListener(
                focusNode: _nameFocus,
                child: TextFormField(
                  focusNode: _nameFocus,
                  initialValue: name,
                  decoration:  InputDecoration(
                    labelText: 'Name'.tr(),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name'.tr();
                    }
                    return null;
                  },
                  onSaved: (value) {
                    name = value!;
                  },
                ),
              ),
              const SizedBox(height: 16),
              DoubleTapKeyboardListener(
                focusNode: _phoneFocus,
                child: TextFormField(
                  focusNode: _phoneFocus,
                  initialValue: phoneNumber,
                  decoration: InputDecoration(
                    labelText: 'Phone Number'.tr(),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a phone number'.tr();
                    }
                    return null;
                  },
                  onSaved: (value) {
                    phoneNumber = value!;
                  },
                ),
              ),
              const SizedBox(height: 16),
              DoubleTapKeyboardListener(
                focusNode: _placeFocus,
                child: TextFormField(
                  focusNode: _placeFocus,
                  initialValue: place,
                  decoration: InputDecoration(
                    labelText: 'Place'.tr(),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a place'.tr();
                    }
                    return null;
                  },
                  onSaved: (value) {
                    place = value!;
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: personProvider.isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          
                          
                          // Create person object
                          final person = Person(
                            id: widget.person?.id,
                            name: name,
                            phoneNumber: phoneNumber,
                            place: place,
                            dateVisited: widget.person?.dateVisited ?? DateTime.now().toIso8601String(),
                            credit: widget.person?.credit ?? 0.0,
                          );
                          
                          try {
                            if (widget.person != null) {
                              await personProvider.updatePerson(person);
                            } else {
                              await personProvider.addPerson(person);
                            }

                            if (!context.mounted) return;
                            final messenger = ScaffoldMessenger.of(context); // ✅ assign first
                            final navigator = Navigator.of(context);  
                            
                            if (personProvider.error.isEmpty) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(widget.person != null ? 'Customer updated successfully'.tr() : 'Customer added successfully'.tr()),
                                ),
                              );
                              navigator.pop();
                            } else {
                              messenger.showSnackBar(
                                SnackBar(content: Text(personProvider.error)),
                              );
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(widget.person != null ? 'Failed to update Customer'.tr() : 'Failed to add Customer'.tr())),
                            );
                          }
                        }
                      },
                child: personProvider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    :  Text('Save'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
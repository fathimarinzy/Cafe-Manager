import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../providers/person_provider.dart';
import '../utils/app_localization.dart';

class PersonFormScreen extends StatefulWidget {
  const PersonFormScreen({super.key});

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String phoneNumber = '';
  String place = '';

  @override
  Widget build(BuildContext context) {
    final personProvider = Provider.of<PersonProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Person Details'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
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
              const SizedBox(height: 16),
              TextFormField(
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
              const SizedBox(height: 16),
              TextFormField(
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: personProvider.isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          
                          // Create person object
                          final person = Person(
                            name: name,
                            phoneNumber: phoneNumber,
                            place: place,
                            dateVisited: DateTime.now().toIso8601String(),
                          );
                          
                          try {
                            await personProvider.addPerson(person);

                            if (!context.mounted) return;
                            final messenger = ScaffoldMessenger.of(context); // ✅ assign first
                            final navigator = Navigator.of(context);  
                            
                            if (personProvider.error.isEmpty) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Person added successfully'.tr()),
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
                              SnackBar(content: Text('Failed to add person'.tr())),
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
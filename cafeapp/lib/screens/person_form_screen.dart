// lib/screens/person_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/person.dart';
import '../providers/person_provider.dart';

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
    final isOffline = personProvider.isOfflineMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Person Details'),
        actions: [
          if (isOffline)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.red, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'Offline',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
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
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
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
                  labelText: 'Place',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a place';
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
                            if (!mounted) return;
                            
                            if (personProvider.error.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    personProvider.isOfflineMode
                                        ? 'Person added locally (offline mode)'
                                        : 'Person added successfully'
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(personProvider.error)),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to add person: $e')),
                            );
                          }
                        }
                      },
                child: personProvider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(personProvider.isOfflineMode
                              ? 'Save Locally'
                              : 'Save'),
                          if (personProvider.isOfflineMode) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.cloud_off, size: 16)
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
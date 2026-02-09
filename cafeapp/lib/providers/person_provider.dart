// lib/providers/person_provider.dart
import 'package:flutter/foundation.dart';
import '../models/person.dart';
import '../repositories/local_person_repository.dart';
import '../services/device_sync_service.dart';

class PersonProvider with ChangeNotifier {
  final LocalPersonRepository _localPersonRepo = LocalPersonRepository();
  
  List<Person> _persons = [];
  List<Person> _searchResults = [];
  bool _isLoading = false;
  String _error = '';
  
  // Getters
  List<Person> get persons => _persons;
  List<Person> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String get error => _error;

  PersonProvider() {
    // No need for connectivity initialization anymore
  }

  Future<void> loadPersons() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Just load from local database
      _persons = await _localPersonRepo.getAllPersons();
      debugPrint('Loaded ${_persons.length} persons from local database');
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading persons: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPerson(Person person) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Save only to local database
      debugPrint('Adding person to local database');
      final newPerson = await _localPersonRepo.savePerson(person);
      debugPrint('Added person locally: ${newPerson.id}');
      
      // Update local state
      _persons.add(newPerson);

      // Sync to Firestore
      DeviceSyncService.syncPersonToFirestore(newPerson);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding person: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchPersons(String query) {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = false; // No async loading needed
    _error = '';
    
    // OPTIMIZATION: Filter in-memory list instead of DB query
    // The _persons list is already loaded by loadPersons()
    try {
      _searchResults = _persons.where((person) => 
        person.name.toLowerCase().contains(query.toLowerCase()) ||
        person.phoneNumber.contains(query)
      ).toList();
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error searching persons: $e');
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }
  
  // Delete a person
  Future<bool> deletePerson(String id) async {
    try {
      final success = await _localPersonRepo.deletePerson(id);
      if (success) {
        // Remove from local lists
        _persons.removeWhere((person) => person.id == id);
        _searchResults.removeWhere((person) => person.id == id);
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting person: $e');
      return false;
    }
  }
  
  // Update person details
  Future<bool> updatePerson(Person person) async {
    if (person.id == null) return false;
    
    try {
      final success = await _localPersonRepo.updatePerson(person);
      if (success) {
        // Update in local lists
        final personsIndex = _persons.indexWhere((p) => p.id == person.id);
        if (personsIndex >= 0) {
          _persons[personsIndex] = person;
        }
        
        
        final searchIndex = _searchResults.indexWhere((p) => p.id == person.id);
        if (searchIndex >= 0) {
          _searchResults[searchIndex] = person;
        }
        
        notifyListeners();
        
        // Sync to Firestore
        DeviceSyncService.syncPersonToFirestore(person);
      }
      return success;
    } catch (e) {
      debugPrint('Error updating person: $e');
      return false;
    }
  }
  // Add method to update customer credit
Future<bool> updateCustomerCredit(String personId, double creditAmount) async {
  try {
    final success = await _localPersonRepo.addCreditToCustomer(personId, creditAmount);
    if (success) {
      // Update local lists
      final personIndex = _persons.indexWhere((p) => p.id == personId);
      if (personIndex >= 0) {
        final updatedPerson = _persons[personIndex].copyWith(
          credit: _persons[personIndex].credit + creditAmount
        );
        _persons[personIndex] = updatedPerson;
      }
      
      final searchIndex = _searchResults.indexWhere((p) => p.id == personId);
      if (searchIndex >= 0) {
        final updatedPerson = _searchResults[searchIndex].copyWith(
          credit: _searchResults[searchIndex].credit + creditAmount
        );
        _searchResults[searchIndex] = updatedPerson;
      }
      
      notifyListeners();

      // Sync updated person to Firestore
      // We need the full updated person object. 
      // If found in _persons (which it should be if update succeeded), use that.
      if (personIndex >= 0) {
         DeviceSyncService.syncPersonToFirestore(_persons[personIndex]);
      }
    }
    return success;
  } catch (e) {
    debugPrint('Error updating customer credit: $e');
    return false;
  }
}

// Add method to get customer by ID
Future<Person?> getPersonById(String personId) async {
  try {
    return await _localPersonRepo.getPersonById(personId);
  } catch (e) {
    debugPrint('Error getting person by ID: $e');
    return null;
  }
  }

  // Reset entire provider state (Factory Reset)
  void resetState() {
    debugPrint('Clearing PersonProvider in-memory state');
    _persons = [];
    _searchResults = [];
    notifyListeners();
  }


}
// lib/providers/person_provider.dart
import 'package:flutter/foundation.dart';
import '../models/person.dart';
import '../repositories/local_person_repository.dart';

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
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding person: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchPersons(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Search only in local database
      final allPersons = await _localPersonRepo.getAllPersons();
      _searchResults = allPersons.where((person) => 
        person.name.toLowerCase().contains(query.toLowerCase()) ||
        person.phoneNumber.contains(query)
      ).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error searching persons: $e');
    } finally {
      _isLoading = false;
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
      }
      return success;
    } catch (e) {
      debugPrint('Error updating person: $e');
      return false;
    }
  }
}
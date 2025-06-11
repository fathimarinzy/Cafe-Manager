// lib/providers/person_provider.dart
import 'package:flutter/foundation.dart';
import '../models/person.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../repositories/local_person_repository.dart';

class PersonProvider with ChangeNotifier {
  final ApiService _apiService;
  final LocalPersonRepository _localPersonRepo = LocalPersonRepository();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  List<Person> _persons = [];
  List<Person> _searchResults = [];
  bool _isLoading = false;
  String _error = '';
  bool _isOfflineMode = false;
  
  // Getters
  List<Person> get persons => _persons;
  List<Person> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String get error => _error;
  bool get isOfflineMode => _isOfflineMode;

  PersonProvider(this._apiService) {
    _initConnectivity();
  }

  // Initialize connectivity monitoring
  Future<void> _initConnectivity() async {
    _isOfflineMode = !await _connectivityService.checkConnection();
    
    // Listen for connectivity changes
    _connectivityService.connectivityStream.listen((isConnected) {
      final wasOffline = _isOfflineMode;
      _isOfflineMode = !isConnected;
      
      // If connection restored, sync pending persons
      if (wasOffline && !_isOfflineMode) {
        debugPrint('Connection restored, syncing persons');
        syncPersons();
      }
      
      notifyListeners();
    });
  }

  Future<void> loadPersons() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      if (_isOfflineMode) {
        // Load from local database
        _persons = await _localPersonRepo.getAllPersons();
        debugPrint('Loaded ${_persons.length} persons from local database');
      } else {
        // Try to load from API
        try {
          _persons = await _apiService.getPersons();
          debugPrint('Loaded ${_persons.length} persons from API');
          
          // Also save API results to local database for offline access
          for (var person in _persons) {
            await _localPersonRepo.savePerson(person);
          }
          debugPrint('Saved all API persons to local database');
        } catch (e) {
          debugPrint('Error loading persons from API: $e');
          // Fallback to local database
          _persons = await _localPersonRepo.getAllPersons();
          debugPrint('Fallback: Loaded ${_persons.length} persons from local database');
        }
      }
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
      Person newPerson;
      
      if (_isOfflineMode) {
        // Save locally only
        debugPrint('Adding person in offline mode');
        newPerson = await _localPersonRepo.savePerson(person);
        debugPrint('Added person locally: ${newPerson.id}');
      } else {
        // Try to save to API first
        try {
          debugPrint('Adding person in online mode');
          newPerson = await _apiService.createPerson(person);
          debugPrint('Added person to API: ${newPerson.id}');
          
          // IMPORTANT: Always save to local DB even when online
          await _localPersonRepo.savePerson(newPerson);
          debugPrint('Also saved person to local database: ${newPerson.id}');
        } catch (e) {
          debugPrint('API error, falling back to local save: $e');
          
          // If API fails, save locally
          newPerson = await _localPersonRepo.savePerson(person);
          debugPrint('Saved person locally after API error: ${newPerson.id}');
          
          // Trigger sync in case connection issues are temporary
          syncPersons();
        }
      }
      
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
      if (_isOfflineMode) {
        // Search locally
        final allPersons = await _localPersonRepo.getAllPersons();
        _searchResults = allPersons.where((person) => 
          person.name.toLowerCase().contains(query.toLowerCase()) ||
          person.phoneNumber.contains(query)
        ).toList();
      } else {
        // Try online search
        try {
          _searchResults = await _apiService.searchPersons(query);
          
          // Save search results to local database for future offline access
          for (var person in _searchResults) {
            await _localPersonRepo.savePerson(person);
          }
        } catch (e) {
          debugPrint('API search error, falling back to local search: $e');
          
          // Fallback to local search
          final allPersons = await _localPersonRepo.getAllPersons();
          _searchResults = allPersons.where((person) => 
            person.name.toLowerCase().contains(query.toLowerCase()) ||
            person.phoneNumber.contains(query)
          ).toList();
        }
      }
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
  
  // Sync pending persons to server
  Future<void> syncPersons() async {
    if (_isOfflineMode) return;
    
    try {
      final unsyncedPersons = await _localPersonRepo.getUnsyncedPersons();
      debugPrint('Found ${unsyncedPersons.length} unsynced persons to sync');
      
      if (unsyncedPersons.isEmpty) return;
      
      for (var person in unsyncedPersons) {
        // Skip already synced persons or those with server IDs
        if (!person.id!.startsWith('local_')) continue;
        
        try {
          // Create person on server
          final serverPerson = await _apiService.createPerson(person);
          
          // Update local record with server ID
          await _localPersonRepo.markPersonAsSynced(person.id!, serverPerson.id);
          
          debugPrint('Synced person successfully: ${person.id} -> ${serverPerson.id}');
        } catch (e) {
          debugPrint('Error syncing person ${person.id}: $e');
        }
      }
      
      // Refresh the persons list
      await loadPersons();
    } catch (e) {
      debugPrint('Error during person sync: $e');
    }
  }
  
  // Get pending operations count
  Future<int> getPendingOperationsCount() async {
    return await _localPersonRepo.getPendingOperationsCount();
  }
  
  // Force check connection and sync
  Future<void> checkConnectionAndSync() async {
    final isConnected = await _connectivityService.checkConnection();
    
    if (isConnected) {
      if (_isOfflineMode) {
        _isOfflineMode = false;
        notifyListeners();
      }
      
      await syncPersons();
    } else {
      if (!_isOfflineMode) {
        _isOfflineMode = true;
        notifyListeners();
      }
    }
  }
}

import 'package:flutter/foundation.dart';
import '../models/person.dart';
import '../services/api_service.dart';

class PersonProvider with ChangeNotifier {
  final ApiService _apiService;
  List<Person> _persons = [];
  List<Person> _searchResults = [];
  bool _isLoading = false;
  String _error = '';

  PersonProvider(this._apiService);

  List<Person> get persons => _persons;
  List<Person> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String get error => _error;

  Future<void> loadPersons() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _persons = await _apiService.getPersons();
    } catch (e) {
      _error = e.toString();
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
      final newPerson = await _apiService.createPerson(person);
      _persons.add(newPerson);
    } catch (e) {
      _error = e.toString();
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
      _searchResults = await _apiService.searchPersons(query);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }
}
 import 'dart:convert';
import 'package:flutter/foundation.dart'; // Add this import for debugPrint
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/person.dart';


class ApiService {

  static const String baseUrl = 'https://ftrinzy.pythonanywhere.com/api'; // Use your backend URL
  final FlutterSecureStorage storage = FlutterSecureStorage();

  Future<String?> getToken() async {
    return await storage.read(key: 'token');
  }

  Future<void> saveToken(String token) async {
    await storage.write(key: 'token', value: token);
  }

  Future<void> deleteToken() async {
    await storage.delete(key: 'token');
  }

  Future<User?> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
   
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['token']);
      return User.fromJson(data['user'], data['token']);
    }
    return null;
  }

  Future<List<MenuItem>> getMenu() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/menu'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => MenuItem.fromJson(item)).toList();
    }
    return [];
  }

  Future<List<String>> getCategories() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/menu/categories'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((category) => category.toString()).toList();
    }
    return [];
  }

  Future<List<MenuItem>> getMenuByCategory(String category) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/menu/category/$category'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => MenuItem.fromJson(item)).toList();
    }
    return [];
  }

  Future<List<Order>> getOrders() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/orders'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((order) => Order.fromJson(order)).toList();
    }
    return [];
  }

  Future<Order?> createOrder(String serviceType, List<Map<String, dynamic>> items, double subtotal, double tax, double discount, double total) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'serviceType': serviceType,
        'items': items,
        'subtotal': subtotal,
        'tax': tax,
        'discount': discount,
        'total': total,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Order.fromJson(data);
    }
    return null;
  }

  Future<void> addToCart(int itemId, int quantity) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'items': [
          {
            'id': itemId,
            'quantity': quantity,
          }
        ],
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add item to order');
    }
  }

  // persons search case 


  Future<Person> createPerson(Person person) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/persons'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(person.toJson()),
      );

      if (response.statusCode == 201) {
        return Person.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create person: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating person: $e');
    }
  }

  Future<List<Person>> getPersons() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/persons'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) {
          // Ensure ID is a string
          if (json['id'] != null) {
            json['id'] = json['id'].toString();
          }
          return Person.fromJson(json);
        }).toList();
      } else {
        throw Exception('Failed to load persons');
      }
    } catch (e) {
      throw Exception('Error loading persons: $e');
    }
  }

  Future<List<Person>> searchPersons(String query) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/persons/search?query=$query'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
       // Make sure each person object has properly formatted data
        return data.map((json) {
          // Ensure ID is a string
          if (json['id'] != null) {
            json['id'] = json['id'].toString();
          }
        return Person.fromJson(json);
      }).toList();
      
      } else {
        throw Exception('Failed to search persons');
      }
    } catch (e) {
      throw Exception('Error searching persons: $e');
    }
  }



//  crud operation
  
Future<MenuItem> addMenuItem(MenuItem item) async {
  final token = await getToken();
  
  // Important: Make sure we're using the correct field name 'image' to match the backend
  final Map<String, dynamic> data = {
    'name': item.name,
    'price': item.price,
    'image': item.imageUrl, // This should match the API's expected field name
    'category': item.category,
    'available': item.isAvailable,
  };

  final response = await http.post(
    Uri.parse('$baseUrl/menu'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(data),
  );

  if (response.statusCode == 201) {
    debugPrint('Menu item added successfully, response: ${response.body}');
    return MenuItem.fromJson(jsonDecode(response.body));
  } else {
    debugPrint('Failed to add menu item, status: ${response.statusCode}, response: ${response.body}');
    throw Exception('Failed to add menu item: ${response.body}');
  }
}

  Future<MenuItem> updateMenuItem(MenuItem item) async {
  final token = await getToken();
  
  // Important: Make sure we're using the correct field name 'image' to match the backend
  final Map<String, dynamic> data = {
    'name': item.name,
    'price': item.price,
    'image': item.imageUrl, // This should match the API's expected field name
    'category': item.category,
    'available': item.isAvailable,
  };

  final response = await http.put(
    Uri.parse('$baseUrl/menu/${item.id}'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(data),
  );

  if (response.statusCode == 200) {
    debugPrint('Menu item updated successfully');
    return MenuItem.fromJson(jsonDecode(response.body));
  } else {
    debugPrint('Failed to update menu item, status: ${response.statusCode}, response: ${response.body}');
    throw Exception('Failed to update menu item: ${response.body}');
  }
}
  Future<void> deleteMenuItem(String id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/menu/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete menu item');
    }
  }
  // Add this method to handle adding new categories
  Future<void> addCategory(String category) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/menu/categories'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': category}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add category');
    }
  }
}   
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

  // New method to get user information using stored token
  Future<User?> getUserInfo() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      // Try to refresh the token first to ensure it's valid
      final refreshResponse = await http.post(
        Uri.parse('$baseUrl/refresh-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (refreshResponse.statusCode == 200) {
        final refreshData = jsonDecode(refreshResponse.body);
        final newToken = refreshData['token'];
        
        // Save the new token
        await saveToken(newToken);
        
        // Create and return user from refresh response
        return User.fromJson(refreshData['user'], newToken);
      } else {
        // Token refresh failed, token might be expired or invalid
        await deleteToken();
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return null;
    }
  }

  Future<User?> login(String username, String password) async {
    try {
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
    } catch (e) {
      debugPrint('Login error: $e');
      return null;
    }
  }

  // Helper method to handle expired tokens
  Future<bool> _handleExpiredToken(http.Response response) async {
    if (response.statusCode == 401) {
      try {
        final token = await getToken();
        if (token == null) return false;

        // Try to refresh the token
        final refreshResponse = await http.post(
          Uri.parse('$baseUrl/refresh-token'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (refreshResponse.statusCode == 200) {
          final refreshData = jsonDecode(refreshResponse.body);
          await saveToken(refreshData['token']);
          return true; // Token refreshed successfully
        } else {
          // Token couldn't be refreshed
          await deleteToken();
          return false;
        }
      } catch (e) {
        debugPrint('Token refresh error: $e');
        await deleteToken();
        return false;
      }
    }
    return false;
  }

  Future<List<MenuItem>> getMenu() async {
    final token = await getToken();
    if (token == null) return [];

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
    } else if (response.statusCode == 401) {
      // Token might be expired, try to refresh
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) {
        // Try the request again with the new token
        return getMenu();
      }
    }
    return [];
  }

  Future<List<String>> getCategories() async {
    final token = await getToken();
    if (token == null) return [];
    
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
    } else if (response.statusCode == 401) {
      // Token might be expired, try to refresh
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) {
        // Try the request again with the new token
        return getCategories();
      }
    }
    return [];
  }

  // Rest of your methods with token refresh handling for each API call...
  // For brevity I'm not showing all methods, but you would add similar token refresh
  // handling to each API method that requires authentication

  Future<List<MenuItem>> getMenuByCategory(String category) async {
    final token = await getToken();
    if (token == null) return [];
    
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
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return getMenuByCategory(category);
    }
    return [];
  }

  Future<List<Order>> getOrders() async {
    final token = await getToken();
    if (token == null) return [];
    
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
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return getOrders();
    }
    return [];
  }

  // Update the createOrder method in ApiService to include kitchen notes

    Future<Order?> createOrder(String serviceType, List<Map<String, dynamic>> items, double subtotal, double tax, double discount, double total) async {
      final token = await getToken();
      if (token == null) return null;
      
      // Make sure each item includes any kitchen notes
      for (var item in items) {
        // Ensure kitchen note is included (if not already)
        if (!item.containsKey('kitchenNote')) {
          item['kitchenNote'] = '';
        }
      }
      
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
      } else if (response.statusCode == 401) {
        final refreshed = await _handleExpiredToken(response);
        if (refreshed) return createOrder(serviceType, items, subtotal, tax, discount, total);
      }
      return null;
    }

  Future<void> addToCart(int itemId, int quantity) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    
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
      if (response.statusCode == 401) {
        final refreshed = await _handleExpiredToken(response);
        if (refreshed) return addToCart(itemId, quantity);
      }
      throw Exception('Failed to add item to order');
    }
  }

  // Persons search case 
  Future<Person> createPerson(Person person) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Not authenticated');
      
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
      } else if (response.statusCode == 401) {
        final refreshed = await _handleExpiredToken(response);
        if (refreshed) return createPerson(person);
      }
      throw Exception('Failed to create person: ${response.body}');
    } catch (e) {
      throw Exception('Error creating person: $e');
    }
  }

  Future<List<Person>> getPersons() async {
    try {
      final token = await getToken();
      if (token == null) return [];
      
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
      } else if (response.statusCode == 401) {
        final refreshed = await _handleExpiredToken(response);
        if (refreshed) return getPersons();
      }
      throw Exception('Failed to load persons');
    } catch (e) {
      throw Exception('Error loading persons: $e');
    }
  }

  Future<List<Person>> searchPersons(String query) async {
    try {
      final token = await getToken();
      if (token == null) return [];
      
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
      } else if (response.statusCode == 401) {
        final refreshed = await _handleExpiredToken(response);
        if (refreshed) return searchPersons(query);
      }
      throw Exception('Failed to search persons');
    } catch (e) {
      throw Exception('Error searching persons: $e');
    }
  }

  // CRUD operations
  Future<MenuItem> addMenuItem(MenuItem item) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    
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
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return addMenuItem(item);
    }
    debugPrint('Failed to add menu item, status: ${response.statusCode}, response: ${response.body}');
    throw Exception('Failed to add menu item: ${response.body}');
  }

  Future<MenuItem> updateMenuItem(MenuItem item) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    
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
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return updateMenuItem(item);
    }
    debugPrint('Failed to update menu item, status: ${response.statusCode}, response: ${response.body}');
    throw Exception('Failed to update menu item: ${response.body}');
  }

  Future<void> deleteMenuItem(String id) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/menu/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Check for success status codes (200, 202, 204)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Menu item deleted successfully: ${response.statusCode}');
        return; // Success case
      } else if (response.statusCode == 401) {
        final refreshed = await _handleExpiredToken(response);
        if (refreshed) return deleteMenuItem(id);
      } else {
        // Log failure details for debugging
        final errorBody = response.body.isNotEmpty ? response.body : 'No response body';
        debugPrint('Failed to delete menu item. Status: ${response.statusCode}, Response: $errorBody');
        
        // Parse error message if available
        String errorMessage = 'Failed to delete menu item';
        if (response.body.isNotEmpty) {
          try {
            final data = jsonDecode(response.body);
            errorMessage = data['message'] ?? errorMessage;
          } catch (_) {
            // Keep default error message if JSON parsing fails
          }
        }
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Exception while deleting menu item: $e');
      throw Exception('Failed to delete menu item: $e');
    }
  }

  // Add this method to handle adding new categories
  Future<void> addCategory(String category) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    
    final response = await http.post(
      Uri.parse('$baseUrl/menu/categories'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': category}),
    );

    if (response.statusCode != 201) {
      if (response.statusCode == 401) {
        final refreshed = await _handleExpiredToken(response);
        if (refreshed) return addCategory(category);
      }
      throw Exception('Failed to add category');
    }
  }

  // Order history methods
  Future<List<Order>> getOrdersByServiceType(String serviceType) async {
    final token = await getToken();
    if (token == null) return [];
    
    final response = await http.get(
      Uri.parse('$baseUrl/orders/service/$serviceType'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((order) => Order.fromJson(order)).toList();
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return getOrdersByServiceType(serviceType);
    }
    return [];
  }

  Future<List<Order>> getOrdersByDateRange(DateTime start, DateTime end) async {
    final token = await getToken();
    if (token == null) return [];
    
    // Format dates as ISO strings for query parameters
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();
    
    final response = await http.get(
      Uri.parse('$baseUrl/orders/date?start=$startStr&end=$endStr'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((order) => Order.fromJson(order)).toList();
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return getOrdersByDateRange(start, end);
    }
    return [];
  }

  Future<Order?> getOrderById(int orderId) async {
  final token = await getToken();
  if (token == null) return null;
  
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Order.fromJson(data);
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return getOrderById(orderId);
    }
    
    return null;
  } catch (e) {
    debugPrint('Error getting order by ID: $e');
    return null;
  }
}

  Future<List<Order>> getOrdersByTable(String tableInfo) async {
    final token = await getToken();
    if (token == null) return [];
    
    // Extract table number from the tableInfo string (e.g., "Dining - Table 1")
    final tableNumber = tableInfo.split('Table ').last;
    
    final response = await http.get(
      Uri.parse('$baseUrl/orders/table/$tableNumber'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((order) => Order.fromJson(order)).toList();
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return getOrdersByTable(tableInfo);
    }
    return [];
  }

  Future<List<Order>> searchOrdersByBillNumber(String billNumber) async {
    final token = await getToken();
    if (token == null) return [];
    
    final response = await http.get(
      Uri.parse('$baseUrl/orders/search?billNumber=$billNumber'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((order) => Order.fromJson(order)).toList();
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return searchOrdersByBillNumber(billNumber);
    }
    return [];
  }

// Update an order's status
Future<bool> updateOrderStatus(int orderId, String status) async {
  try {
    final token = await getToken();
    if (token == null) return false;
    
    final response = await http.put(
      Uri.parse('$baseUrl/orders/$orderId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'status': status
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('Order status updated successfully: $status');
      return true;
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return updateOrderStatus(orderId, status);
    }
    debugPrint('Failed to update order status: ${response.body}');
    return false;
  } catch (e) {
    debugPrint('Error updating order status: $e');
    return false;
  }
}
// Add this method to ApiService class

  Future<Order?> updateOrder(
    int orderId, 
    String serviceType, 
    List<Map<String, dynamic>> items,
    double subtotal, 
    double tax, 
    double discount, 
    double total
  ) async {
    final token = await getToken();
    if (token == null) return null;
    
    // Create the update payload
    final Map<String, dynamic> payload = {
      'serviceType': serviceType,
      'items': items,
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'status': 'pending', // Keep status as pending for active orders
    };
    
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('Order updated successfully: ${response.body}');
        return Order.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 401) {
        final refreshed = await _handleExpiredToken(response);
        if (refreshed) {
          return updateOrder(orderId, serviceType, items, subtotal, tax, discount, total);
        }
      }
      
      debugPrint('Failed to update order: ${response.statusCode}, ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error updating order: $e');
      return null;
    }
  }

 // Update the createExpense method in the ApiService class
Future<bool> createExpense(Map<String, dynamic> expenseData) async {
  try {
    final token = await getToken();
    if (token == null) return false;
    
    // Remove unnecessary fields that aren't supported by backend
    final Map<String, dynamic> filteredData = {
      'date': expenseData['date'],
      'cashier': expenseData['cashier'],
      'accountType': expenseData['accountType'], // Include the account type
      'items': expenseData['items'],
      'grandTotal': expenseData['grandTotal'],
    };
    
    final response = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(filteredData),
    );
    
    if (response.statusCode == 201) {
      debugPrint('Expense created successfully');
      return true;
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return createExpense(expenseData);
    }
    
    debugPrint('Failed to create expense: ${response.body}');
    return false;
  } catch (e) {
    debugPrint('Error creating expense: $e');
    return false;
  }
}

// Get all expenses
Future<List<Map<String, dynamic>>> getExpenses() async {
  try {
    final token = await getToken();
    if (token == null) return [];
    
    final response = await http.get(
      Uri.parse('$baseUrl/expenses'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((expense) => expense as Map<String, dynamic>).toList();
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return getExpenses();
    }
    
    return [];
  } catch (e) {
    debugPrint('Error getting expenses: $e');
    return [];
  }
}

// Get a specific expense by ID
Future<Map<String, dynamic>?> getExpenseById(int id) async {
  try {
    final token = await getToken();
    if (token == null) return null;
    
    final response = await http.get(
      Uri.parse('$baseUrl/expenses/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return getExpenseById(id);
    }
    
    return null;
  } catch (e) {
    debugPrint('Error getting expense by ID: $e');
    return null;
  }
}

// Delete an expense
Future<bool> deleteExpense(int id) async {
  try {
    final token = await getToken();
    if (token == null) return false;
    
    final response = await http.delete(
      Uri.parse('$baseUrl/expenses/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 401) {
      final refreshed = await _handleExpiredToken(response);
      if (refreshed) return deleteExpense(id);
    }
    
    return false;
  } catch (e) {
    debugPrint('Error deleting expense: $e');
    return false;
  }
}
}
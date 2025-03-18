import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class OrderProvider with ChangeNotifier {
  final List<MenuItem> _cartItems = [];
  double _subtotal = 0;
  double _tax = 0;
  double _discount = 0;
  double _total = 0;
  final ApiService _apiService = ApiService();

  List<MenuItem> get cartItems => [..._cartItems];
  double get subtotal => _subtotal;
  double get tax => _tax;
  double get discount => _discount;
  double get total => _total;

  void addToCart(MenuItem item) {
    final existingIndex = _cartItems.indexWhere((cartItem) => cartItem.id == item.id);

    if (existingIndex >= 0) {
      _cartItems[existingIndex].quantity += 1;
    } else {
      _cartItems.add(item..quantity = 1);
    }
    _updateTotals();
    notifyListeners();
  }

  void updateItemQuantity(String id, int quantity) {
    final itemIndex = _cartItems.indexWhere((item) => item.id == id);
    if (itemIndex >= 0) {
      _cartItems[itemIndex].quantity = quantity > 0 ? quantity : 1; // Ensure min quantity is 1
      _updateTotals();
      notifyListeners();
    }
  }

  void removeFromCart(String id) {
    try {
      final cartItem = _cartItems.firstWhere((item) => item.id == id);
      if (cartItem.quantity > 1) {
        cartItem.quantity -= 1;
      } else {
        _cartItems.remove(cartItem);
      }
      _updateTotals();
      notifyListeners();
    } catch (e) {
      debugPrint('Item not found in cart: $e');
    }
  }

  void removeItem(String id) {
    _cartItems.removeWhere((item) => item.id == id);
    _updateTotals();
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _updateTotals();
    notifyListeners();
  }

  void _updateTotals() {
    _subtotal = _cartItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
    _tax = _subtotal * 0.05;
    _total = (_subtotal + _tax - _discount).clamp(0, double.infinity);
  }

  void setDiscount(double discount) {
    _discount = discount >= 0 ? discount : 0;
    _updateTotals();
    notifyListeners();
  }

  Future<bool> placeOrder(String serviceType) async {
    if (_cartItems.isEmpty) return false;

    try {
      final items = _cartItems.map((item) => item.toJson()).toList();
      final order = await _apiService.createOrder(
        serviceType,
        items,
        _subtotal,
        _tax,
        _discount,
        _total,
      );

      if (order != null) {
        clearCart();
        return true;
      }
      return false;
    } catch (error) {
      debugPrint('Error placing order: $error');
      return false;
    }
  }

  Future<List<Order>> fetchOrders() async {
    try {
      return await _apiService.getOrders();
    } catch (error) {
      debugPrint('Error fetching orders: $error');
      return [];
    }
  }
}

import '../models/menu_item.dart';
import '../models/order_item.dart';

extension OrderItemExtension on OrderItem {
  MenuItem toMenuItem() {
    return MenuItem(
      id: id.toString(),
      name: name,
      price: price,
      imageUrl: '',
      category: '',
      quantity: quantity,
    );
  }
}
// Extension to capitalize a string
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
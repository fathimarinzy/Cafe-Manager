import 'package:flutter/material.dart';
import '../models/order_history.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final OrderHistory order;
  final bool isPrinted;
  final bool isPdfSaved;

  const PaymentSuccessScreen({
    super.key, 
    required this.order,
    this.isPrinted = false,
    this.isPdfSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Successful!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Order #${order.orderNumber} has been paid',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (isPrinted)
              const Text('Receipt has been printed'),
            if (isPdfSaved)
              const Text('Receipt has been saved as PDF'),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                // Navigate back to order list
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
              ),
              child: const Text('Return to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
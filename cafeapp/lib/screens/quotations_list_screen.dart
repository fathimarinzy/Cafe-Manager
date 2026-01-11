import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/bill_service.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../services/cross_platform_pdf_service.dart';
import '../providers/order_provider.dart';
import '../providers/order_history_provider.dart';
import '../utils/app_localization.dart';

class QuotationsListScreen extends StatefulWidget {
  const QuotationsListScreen({super.key});

  @override
  State<QuotationsListScreen> createState() => _QuotationsListScreenState();
}

class _QuotationsListScreenState extends State<QuotationsListScreen> {
  bool _isLoading = true;
  List<Order> _quotations = [];

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  Future<void> _loadQuotations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    // We can use OrderProvider to fetch all orders and filter by status 'quote'
    // Or add a specific method in provider/repo. For now, we'll fetch all.
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final allOrders = await orderProvider.fetchOrders(); // This hits the repo
    
    // Filter for quotes locally
    final quotes = allOrders.where((o) => o.status.toLowerCase() == 'quote').toList();
    
    // Sort by date desc
    quotes.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));

    if (mounted) {
      setState(() {
        _quotations = quotes;
        _isLoading = false;
      });
    }
  }

  Future<void> _convertToOrder(Order quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Convert to Order?'.tr()),
        content: Text('This will move the quotation to active orders.'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Convert'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (quote.id == null) return;
      final success = await orderProvider.convertQuoteToOrder(quote.id!);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Converted to Order successfully'.tr()), backgroundColor: Colors.green),
          );
          
          // Refresh OrderHistoryProvider so it shows up in the orders list
          if (mounted) {
            try {
              Provider.of<OrderHistoryProvider>(context, listen: false).loadOrders();
            } catch (e) {
              debugPrint('Error refreshing history: $e');
            }
          }

          _loadQuotations(); // Refresh list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Failed to convert'.tr()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Quotations'.tr(), style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQuotations,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _quotations.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No Quotations Found'.tr(), style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _quotations.length,
                itemBuilder: (context, index) {
                  final quote = _quotations[index];
                  final date = DateTime.tryParse(quote.createdAt ?? '') ?? DateTime.now();
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${'Quote'.tr()} #${quote.id}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'QUOTE',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('${'Date'.tr()}: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}'),
                          Text('${'Service'.tr()}: ${quote.serviceType}'),
                          if (quote.customerId != null)
                             Text('${'Customer ID'.tr()}: ${quote.customerId}'),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${'Items'.tr()}: ${quote.items.length}'),
                                  Text(
                                    '${'Total'.tr()}: ${NumberFormat.currency(symbol: '').format(quote.total)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.share, size: 16),
                                    label: Text('Share'.tr()),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                    ),
                                    onPressed: () {
                                      _shareQuote(quote);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _convertToOrder(quote),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text('Convert to Order'.tr()),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Future<void> _shareQuote(Order quote) async {
    try {
      // Convert Order Items to MenuItems for generation
      final menuItems = quote.items.map((item) => MenuItem(
        id: item.id.toString(),
        name: item.name,
        price: item.price,
        imageUrl: '',
        category: '',
        isAvailable: true,
        quantity: item.quantity,
        kitchenNote: item.kitchenNote,
        taxExempt: item.taxExempt,
      )).toList();

      final pdf = await BillService.generateBill(
        items: menuItems,
        serviceType: quote.serviceType,
        subtotal: quote.subtotal,
        tax: quote.tax,
        discount: quote.discount,
        total: quote.total,
        personName: quote.customerId, // Should ideally fetch name
        orderNumber: quote.id.toString(),
        title: 'QUOTATION',
        // Note: Tax rate isn't stored in Order, ideally pass it or fetch from settings
      );

      await CrossPlatformPdfService.sharePdf(pdf, fileName: 'Quote_${quote.id}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing quote: $e')),
        );
      }
    }
  }
}

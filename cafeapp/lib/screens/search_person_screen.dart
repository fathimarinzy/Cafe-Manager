import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/person_provider.dart';
import '../utils/app_localization.dart';
import '../models/person.dart';
import '../repositories/credit_transaction_repository.dart';
import '../models/order_history.dart';
import '../screens/tender_screen.dart';
import '../models/credit_transaction.dart';
import 'person_form_screen.dart'; // Add import
import '../utils/keyboard_utils.dart';

class SearchPersonScreen extends StatefulWidget {
    final bool isForCreditReceipt;

  const SearchPersonScreen({super.key, this.isForCreditReceipt = false});

  @override
  SearchPersonScreenState createState() => SearchPersonScreenState();
}

class SearchPersonScreenState extends State<SearchPersonScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Load all persons when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PersonProvider>(context, listen: false).loadPersons();
    });
  }
    // Add this method to show credit transactions
  Future<void> _showCreditTransactions(Person person) async {
    final creditRepo = CreditTransactionRepository();
    final transactions = await creditRepo.getCreditTransactionsByCustomer(person.id!);
    
    if (!mounted) return;
    
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'No pending credit transactions for'.tr()} ${person.name}'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${'Credit Transactions -'.tr()} ${person.name}'.tr()),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Credit Balance:'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        person.credit.toStringAsFixed(3),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: Icon(
                              Icons.credit_card,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                          ),
                          title: Text('${'Order #'.tr()}${transaction.orderNumber}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${'Amount:'.tr()} ${transaction.amount.toStringAsFixed(3)}'),
                              Text(
                                '${'Date:'.tr()} ${DateFormat('dd-MM-yyyy HH:mm').format(transaction.createdAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                transaction.serviceType,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.of(context).pop(); // Close credit list dialog
                            _navigateToTenderForCredit(transaction, person);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'.tr()),
            ),
          ],
        );
      },
    );
  }

  // Add this method to navigate to tender for credit completion
  Future<void> _navigateToTenderForCredit(CreditTransaction transaction, Person person) async {
    // Create a dummy order for the tender screen
    final dummyOrder = OrderHistory(
      id: int.tryParse(transaction.orderNumber) ?? 0, // Use 0 to indicate this is a credit completion, not a real order
      serviceType: transaction.serviceType,
      total: transaction.amount,
      status: 'credit_completion'.tr(),
      createdAt: transaction.createdAt,
      items: [], // Empty items since this is just for credit completion
      customerId: person.id,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TenderScreen(
          order: dummyOrder,
          isEdited: false,
          taxRate: 0.0, // No tax for credit completion
          customer: person,
          isCreditCompletion: true,
          creditTransactionId: transaction.id,
        ),
      ),
    );

    if (result == true) {
      // Refresh the person list to update credit balance
      if (mounted) {
        Provider.of<PersonProvider>(context, listen: false).loadPersons();
      }
    }
  }

   
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isForCreditReceipt ? 'Customers'.tr() : 'Customers'.tr()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Consumer<PersonProvider>(
              builder: (ctx, personProvider, child) {
                return DoubleTapKeyboardListener(
                  focusNode: _searchFocus,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      labelText: 'Search by name'.tr(),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _isSearching = false;
                                });
                                personProvider.clearSearch();
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _isSearching = value.isNotEmpty;
                      });
                      if (_isSearching) {
                        personProvider.searchPersons(value);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Consumer<PersonProvider>(
              builder: (ctx, personProvider, child) {
                if (personProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (personProvider.error.isNotEmpty) {
                  return Center(child: Text('Error: ${personProvider.error}'));
                }
                
                final displayList = _isSearching 
                    ? personProvider.searchResults 
                    : personProvider.persons;
                
                if (displayList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_isSearching
                            ? 'No results found'.tr()
                            : 'No Customers added yet'.tr()),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: displayList.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final person = displayList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withAlpha(26),
                          child: Text(
                            person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          person.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            if (person.phoneNumber.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(person.phoneNumber, style: TextStyle(color: Colors.grey[800])),
                                ],
                              ),
                            if (person.place.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(person.place, style: TextStyle(color: Colors.grey[800])),
                                ],
                              ),
                            const SizedBox(height: 4),
                             Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: person.credit > 0 ? Colors.red.withAlpha(26) : Colors.green.withAlpha(26),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${'Credit:'.tr()} ${person.credit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: person.credit > 0 ? Colors.red[700] : Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                                '${'Visited On :'.tr()} ${DateTime.parse(person.dateVisited).toString().substring(0, 10)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                            )
                          ],
                        ),

                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (person.credit > 0)
                              IconButton(
                                icon: const Icon(Icons.credit_card, size: 30),
                                onPressed: () => _showCreditTransactions(person),
                                tooltip: 'Credit List',
                              ),
                             IconButton(
                              icon: const Icon(Icons.edit,color: Colors.grey),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PersonFormScreen(person: person),
                                  ),
                                ).then((_) {
                                   if (context.mounted) {
                                      Provider.of<PersonProvider>(context, listen: false).loadPersons();
                                   }
                                });
                              },
                              tooltip: 'Edit Customer',
                            ),
                          ],
                        ),
                        
                        onTap: () {
                          // Return the selected person when tapped
                          Navigator.of(context).pop(person);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add person screen
          Navigator.of(context).pushNamed('/add-person');
          // When coming back, refresh the list
          Provider.of<PersonProvider>(context, listen: false).loadPersons();
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
}
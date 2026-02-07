// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// // import 'package:intl/intl.dart';
// import 'package:cafeapp/utils/app_localization.dart';
// import '../providers/person_provider.dart';
// import 'person_form_screen.dart';
// // import '../models/person.dart';

// class CustomerManagementScreen extends StatefulWidget {
//   const CustomerManagementScreen({super.key});

//   @override
//   State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
// }

// class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   bool _isSearching = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       Provider.of<PersonProvider>(context, listen: false).loadPersons();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Customers'.tr()),
//         elevation: 0,
//       ),
//       body: Column(
//         children: [
//           // Search Bar
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Consumer<PersonProvider>(
//               builder: (ctx, personProvider, child) {
//                 return TextField(
//                   controller: _searchController,
//                   decoration: InputDecoration(
//                     labelText: 'Search by name'.tr(),
//                     prefixIcon: const Icon(Icons.search),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     suffixIcon: _searchController.text.isNotEmpty
//                         ? IconButton(
//                             icon: const Icon(Icons.clear),
//                             onPressed: () {
//                               _searchController.clear();
//                               setState(() {
//                                 _isSearching = false;
//                               });
//                               personProvider.clearSearch();
//                             },
//                           )
//                         : null,
//                   ),
//                   onChanged: (value) {
//                     setState(() {
//                       _isSearching = value.isNotEmpty;
//                     });
//                     if (_isSearching) {
//                       personProvider.searchPersons(value);
//                     }
//                   },
//                 );
//               },
//             ),
//           ),
          
//           // Customer List
//           Expanded(
//             child: Consumer<PersonProvider>(
//               builder: (ctx, personProvider, child) {
//                 if (personProvider.isLoading) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
                
//                 if (personProvider.error.isNotEmpty) {
//                   return Center(child: Text('Error: ${personProvider.error}'));
//                 }
                
//                 final displayList = _isSearching 
//                     ? personProvider.searchResults 
//                     : personProvider.persons;
                
//                 if (displayList.isEmpty) {
//                   return Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
//                         const SizedBox(height: 16),
//                         Text(
//                           _isSearching
//                               ? 'No results found'.tr()
//                               : 'No customers added yet'.tr(),
//                           style: TextStyle(color: Colors.grey[600], fontSize: 16),
//                         ),
//                       ],
//                     ),
//                   );
//                 }
                
//                 return ListView.builder(
//                   itemCount: displayList.length,
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   itemBuilder: (context, index) {
//                     final person = displayList[index];
//                     return Card(
//                       margin: const EdgeInsets.only(bottom: 12),
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                       elevation: 2,
//                       child: ListTile(
//                         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                         leading: CircleAvatar(
//                           backgroundColor: Colors.blue.withAlpha(26),
//                           child: Text(
//                             person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
//                             style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
//                           ),
//                         ),
//                         title: Text(
//                           person.name,
//                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                         ),
//                         subtitle: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const SizedBox(height: 4),
//                             if (person.phoneNumber.isNotEmpty)
//                               Row(
//                                 children: [
//                                   Icon(Icons.phone, size: 14, color: Colors.grey[600]),
//                                   const SizedBox(width: 4),
//                                   Text(person.phoneNumber, style: TextStyle(color: Colors.grey[800])),
//                                 ],
//                               ),
//                             if (person.place.isNotEmpty)
//                               Row(
//                                 children: [
//                                   Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
//                                   const SizedBox(width: 4),
//                                   Text(person.place, style: TextStyle(color: Colors.grey[800])),
//                                 ],
//                               ),
//                             const SizedBox(height: 4),
//                             Container(
//                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                               decoration: BoxDecoration(
//                                 color: person.credit > 0 ? Colors.red.withAlpha(26) : Colors.green.withAlpha(26),
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               child: Text(
//                                 '${'Credit:'.tr()} ${person.credit.toStringAsFixed(2)}',
//                                 style: TextStyle(
//                                   color: person.credit > 0 ? Colors.red[700] : Colors.green[700],
//                                   fontWeight: FontWeight.w600,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ),
//                             Text(
//                                 '${'Visited On :'.tr()} ${DateTime.parse(person.dateVisited).toString().substring(0, 10)}',
//                                 style: const TextStyle(fontSize: 12, color: Colors.grey),
//                             )
//                           ],
//                         ),
//                         trailing: IconButton(
//                           icon: const Icon(Icons.edit, color: Colors.grey),
//                           onPressed: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => PersonFormScreen(person: person),
//                               ),
//                             ).then((_) {
//                                if (context.mounted) {
//                                  Provider.of<PersonProvider>(context, listen: false).loadPersons();
//                                }
//                             });
//                           },
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () {
//            Navigator.of(context).pushNamed('/add-person').then((_) {
//              // Refresh list on return
//              if (!context.mounted) return;
//              Provider.of<PersonProvider>(context, listen: false).loadPersons();
//            });
//         },
//         label: Text('Add Customer'.tr()),
//         icon: const Icon(Icons.person_add),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
// }

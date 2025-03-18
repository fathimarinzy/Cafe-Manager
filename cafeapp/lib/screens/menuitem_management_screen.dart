// class MenuItemManagementScreen extends StatelessWidget {
//   const MenuItemManagementScreen({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final menuProvider = Provider.of<MenuProvider>(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Menu Item Management'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.add),
//             onPressed: () {
//               Navigator.of(context).push(
//                 MaterialPageRoute(
//                   builder: (context) => const ModifierScreen(),
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//       body: menuProvider.items.isEmpty
//           ? const Center(child: Text('No menu items found'))
//           : ListView.builder(
//               itemCount: menuProvider.items.length,
//               itemBuilder: (ctx, index) {
//                 final item = menuProvider.items[index];
//                 return Card(
//                   margin: const EdgeInsets.symmetric(
//                     horizontal: 16.0, 
//                     vertical: 8.0
//                   ),
//                   child: ListTile(
//                     leading: CircleAvatar(
//                       backgroundImage: NetworkImage(item.imageUrl),
//                     ),
//                     title: Text(item.name),
//                     subtitle: Text(
//                       '${item.price.toStringAsFixed(3)} | ${item.category}',
//                     ),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(
//                           item.isAvailable ? 'Available' : 'Out of stock',
//                           style: TextStyle(
//                             color: item.isAvailable ? Colors.green : Colors.red,
//                           ),
//                         ),
//                         IconButton(
//                           icon: const Icon(Icons.edit),
//                           onPressed: () {
//                             Navigator.of(context).push(
//                               MaterialPageRoute(
//                                 builder: (context) => ModifierScreen(menuItem: item),
//                               ),
//                             );
//                           },
//                         ),
//                       ],
//                     ),
//                     onTap: () {
//                       Navigator.of(context).push(
//                         MaterialPageRoute(
//                           builder: (context) => ModifierScreen(menuItem: item),
//                         ),
//                       );
//                     },
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }
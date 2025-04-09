import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../models/table_model.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final tableProvider = Provider.of<TableProvider>(context);
    final tables = tableProvider.tables;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tables'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Show add dialog with empty fields
              _showAddTableDialog(context);
            },
          ),
        ],
      ),
      body: tables.isEmpty
          ? const Center(child: Text('No tables available. Add a table to get started.'))
          : ListView.builder(
              itemCount: tables.length,
              itemBuilder: (ctx, index) {
                final table = tables[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: table.isOccupied ? Colors.red : Colors.green,
                      child: Text(
                        table.number.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text('Table ${table.number}'),
                    subtitle: Text('Capacity: ${table.capacity} | ${table.isOccupied ? 'Occupied' : 'Available'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Toggle status button
                        IconButton(
                          icon: Icon(
                            table.isOccupied ? Icons.event_busy : Icons.event_available,
                            color: table.isOccupied ? Colors.red : Colors.green,
                          ),
                          onPressed: () {
                            tableProvider.toggleTableStatus(table.id);
                          },
                        ),
                        // Edit button
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            _showEditTableDialog(context, table);
                          },
                        ),
                        // Delete button
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _confirmDelete(context, table);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, TableModel table) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Table ${table.number}?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Provider.of<TableProvider>(context, listen: false).deleteTable(table.id);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  // Separate method for adding a table (with empty fields)
  void _showAddTableDialog(BuildContext context) {
    final numberController = TextEditingController();
    final capacityController = TextEditingController();
    final noteController = TextEditingController();
    bool isOccupied = false;

    // Get the screen width and height to calculate dialog dimensions
    final screenSize = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // Dialog width - using 80% of screen width, with max width
    final dialogWidth = screenSize.width * 0.8 > 500 ? 500.0 : screenSize.width * 0.8;

    // Use a scrollable builder to handle keyboard pushing content
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            // Specify custom width for the dialog
            insetPadding: EdgeInsets.symmetric(
              horizontal: (screenSize.width - dialogWidth) / 2,
              vertical: 24,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: keyboardHeight > 0 ? keyboardHeight : 0,
                ),
                child: Container(
                  width: dialogWidth,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dialog title
                      const Text(
                        'Add Table',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Form content
                      TextField(
                        controller: numberController,
                        decoration: const InputDecoration(
                          labelText: 'Table Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Capacity',
                          border: OutlineInputBorder(),
                          helperText: 'Number of seats at this table',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          border: OutlineInputBorder(),
                          helperText: 'Optional information about this table',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Table Status'),
                        subtitle: Text(isOccupied ? 'Occupied' : 'Available'),
                        value: isOccupied,
                        activeColor: Colors.red,
                        inactiveTrackColor: const Color.fromRGBO(76, 175, 80, 0.5),
                        onChanged: (value) {
                          setState(() {
                            isOccupied = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            child: const Text('Add'),
                            onPressed: () {
                              // Validate inputs
                              final number = int.tryParse(numberController.text);
                              final capacity = int.tryParse(capacityController.text);
                              
                              if (number == null || number <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid table number'))
                                );
                                return;
                              }
                              
                              if (capacity == null || capacity <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid capacity'))
                                );
                                return;
                              }
                              
                              final newTable = TableModel(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                number: number,
                                capacity: capacity,
                                isOccupied: isOccupied,
                                note: noteController.text,
                              );
                              
                              Provider.of<TableProvider>(context, listen: false)
                                .addSpecificTable(newTable);
                              
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Method for editing an existing table
  void _showEditTableDialog(BuildContext context, TableModel table) {
    final numberController = TextEditingController(text: table.number.toString());
    final capacityController = TextEditingController(text: table.capacity.toString());
    final noteController = TextEditingController(text: table.note);
    bool isOccupied = table.isOccupied;

    // Get the screen width and height to calculate dialog dimensions
    final screenSize = MediaQuery.of(context).size;
    // final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // Dialog width - using 80% of screen width, but limiting to a reasonable size
    final dialogWidth = screenSize.width * 0.8 > 500 ? 500.0 : screenSize.width * 0.8;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          // Get updated keyboard height inside the builder
          final updatedKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          
          return Dialog(
            // Specify custom width for the dialog
            insetPadding: EdgeInsets.symmetric(
              horizontal: (screenSize.width - dialogWidth) / 2,
              vertical: 24,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: updatedKeyboardHeight > 0 ? updatedKeyboardHeight : 0,
                ),
                child: Container(
                  width: dialogWidth,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dialog title
                      Text(
                        'Edit Table ${table.number}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Form content
                      TextField(
                        controller: numberController,
                        decoration: const InputDecoration(
                          labelText: 'Table Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Capacity',
                          border: OutlineInputBorder(),
                          helperText: 'Number of seats at this table',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          border: OutlineInputBorder(),
                          helperText: 'Optional information about this table',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Table Status'),
                        subtitle: Text(isOccupied ? 'Occupied' : 'Available'),
                        value: isOccupied,
                        activeColor: Colors.red,
                        inactiveTrackColor: const Color.fromRGBO(76, 175, 80, 0.5),
                        onChanged: (value) {
                          setState(() {
                            isOccupied = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            child: const Text('Save'),
                            onPressed: () {
                              // Validate inputs
                              final number = int.tryParse(numberController.text);
                              final capacity = int.tryParse(capacityController.text);
                              
                              if (number == null || number <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid table number'))
                                );
                                return;
                              }
                              
                              if (capacity == null || capacity <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid capacity'))
                                );
                                return;
                              }
                              
                              final updatedTable = TableModel(
                                id: table.id,
                                number: number,
                                capacity: capacity,
                                isOccupied: isOccupied,
                                note: noteController.text,
                              );
                              
                              Provider.of<TableProvider>(context, listen: false)
                                .updateTable(updatedTable);
                              
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
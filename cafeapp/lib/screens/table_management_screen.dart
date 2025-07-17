import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../models/table_model.dart';
import '../utils/app_localization.dart';

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
        title: Text('Tables'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddTableDialog(context);
            },
          ),
        ],
      ),
      body: tables.isEmpty
          ? Center(child: Text('No tables available. Add a table to get started.'.tr()))
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
                    title: Text('${'Table'.tr()} ${table.number}'),
                    subtitle: Text('${'Capacity'.tr()}: ${table.capacity} | ${table.isOccupied ? 'Occupied'.tr() : 'Available'.tr()}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            table.isOccupied ? Icons.event_busy : Icons.event_available,
                            color: table.isOccupied ? Colors.red : Colors.green,
                          ),
                          onPressed: () {
                            tableProvider.toggleTableStatus(table.id);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            _showEditTableDialog(context, table);
                          },
                        ),
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
        title: Text('${'Delete Table'.tr()} ${table.number}?'),
        content: Text('This action cannot be undone.'.tr()),
        actions: [
          TextButton(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text('Delete'.tr(), style: const TextStyle(color: Colors.red)),
            onPressed: () {
              Provider.of<TableProvider>(context, listen: false).deleteTable(table.id);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showAddTableDialog(BuildContext context) {
    final numberController = TextEditingController();
    final capacityController = TextEditingController();
    final noteController = TextEditingController();
    bool isOccupied = false;

    final screenSize = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final dialogWidth = screenSize.width * 0.8 > 500 ? 500.0 : screenSize.width * 0.8;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
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
                      Text(
                        'Add Table'.tr(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      TextField(
                        controller: numberController,
                        decoration: InputDecoration(
                          labelText: 'Table Number'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: capacityController,
                        decoration: InputDecoration(
                          labelText: 'Capacity'.tr(),
                          border: const OutlineInputBorder(),
                          helperText: 'Number of seats at this table'.tr(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'Note'.tr(),
                          border: const OutlineInputBorder(),
                          helperText: 'Optional information about this table'.tr(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text('Table Status'.tr()),
                        subtitle: Text(isOccupied ? 'Occupied'.tr() : 'Available'.tr()),
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
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text('Cancel'.tr()),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            child: Text('Add'.tr()),
                            onPressed: () {
                              final number = int.tryParse(numberController.text);
                              final capacity = int.tryParse(capacityController.text);
                              
                              if (number == null || number <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Please enter a valid table number'.tr()))
                                );
                                return;
                              }
                              
                              if (capacity == null || capacity <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Please enter a valid capacity'.tr()))
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

  void _showEditTableDialog(BuildContext context, TableModel table) {
    final numberController = TextEditingController(text: table.number.toString());
    final capacityController = TextEditingController(text: table.capacity.toString());
    final noteController = TextEditingController(text: table.note);
    bool isOccupied = table.isOccupied;

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.8 > 500 ? 500.0 : screenSize.width * 0.8;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final updatedKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          
          return Dialog(
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
                      Text(
                        '${'Edit Table'.tr()} ${table.number}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      TextField(
                        controller: numberController,
                        decoration: InputDecoration(
                          labelText: 'Table Number'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: capacityController,
                        decoration: InputDecoration(
                          labelText: 'Capacity'.tr(),
                          border: const OutlineInputBorder(),
                          helperText: 'Number of seats at this table'.tr(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'Note'.tr(),
                          border: const OutlineInputBorder(),
                          helperText: 'Optional information about this table'.tr(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text('Table Status'.tr()),
                        subtitle: Text(isOccupied ? 'Occupied'.tr() : 'Available'.tr()),
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
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text('Cancel'.tr()),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            child: Text('Save'.tr()),
                            onPressed: () {
                              final number = int.tryParse(numberController.text);
                              final capacity = int.tryParse(capacityController.text);
                              
                              if (number == null || number <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Please enter a valid table number'.tr()))
                                );
                                return;
                              }
                              
                              if (capacity == null || capacity <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Please enter a valid capacity'.tr()))
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
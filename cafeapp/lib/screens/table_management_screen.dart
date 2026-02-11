import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/table_provider.dart';
import '../models/table_model.dart';
import '../utils/app_localization.dart';
import '../utils/keyboard_utils.dart';

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
    showDialog(
      context: context,
      builder: (ctx) => const _AddTableDialog(),
    );
  }

  void _showEditTableDialog(BuildContext context, TableModel table) {
    showDialog(
      context: context,
      builder: (ctx) => _EditTableDialog(table: table),
    );
  }
}

class _AddTableDialog extends StatefulWidget {
  const _AddTableDialog();

  @override
  State<_AddTableDialog> createState() => _AddTableDialogState();
}

class _AddTableDialogState extends State<_AddTableDialog> {
  final _numberController = TextEditingController();
  final _capacityController = TextEditingController();
  final _noteController = TextEditingController();
  final _numberFocus = FocusNode();
  final _capacityFocus = FocusNode();
  final _noteFocus = FocusNode();
  bool _isOccupied = false;

  @override
  void dispose() {
    _numberController.dispose();
    _capacityController.dispose();
    _noteController.dispose();
    _numberFocus.dispose();
    _capacityFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final dialogWidth = screenSize.width * 0.8 > 500 ? 500.0 : screenSize.width * 0.8;

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
                
                DoubleTapKeyboardListener(
                  focusNode: _numberFocus,
                  child: TextField(
                    controller: _numberController,
                    focusNode: _numberFocus,
                    decoration: InputDecoration(
                      labelText: 'Table Number'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 16),
                DoubleTapKeyboardListener(
                  focusNode: _capacityFocus,
                  child: TextField(
                    controller: _capacityController,
                    focusNode: _capacityFocus,
                    decoration: InputDecoration(
                      labelText: 'Capacity'.tr(),
                      border: const OutlineInputBorder(),
                      helperText: 'Number of seats at this table'.tr(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 16),
                DoubleTapKeyboardListener(
                  focusNode: _noteFocus,
                  child: TextField(
                    controller: _noteController,
                    focusNode: _noteFocus,
                    decoration: InputDecoration(
                      labelText: 'Note'.tr(),
                      border: const OutlineInputBorder(),
                      helperText: 'Optional information about this table'.tr(),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Table Status'.tr()),
                  subtitle: Text(_isOccupied ? 'Occupied'.tr() : 'Available'.tr()),
                  value: _isOccupied,
                  activeColor: Colors.red,
                  inactiveTrackColor: const Color.fromRGBO(76, 175, 80, 0.5),
                  onChanged: (value) {
                    setState(() {
                      _isOccupied = value;
                    });
                  },
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text('Cancel'.tr()),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      child: Text('Add'.tr()),
                      onPressed: () {
                        final number = int.tryParse(_numberController.text);
                        final capacity = int.tryParse(_capacityController.text);
                        
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
                          isOccupied: _isOccupied,
                          note: _noteController.text,
                        );
                        
                        Provider.of<TableProvider>(context, listen: false)
                          .addSpecificTable(newTable);
                        
                        Navigator.of(context).pop();
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
  }
}

class _EditTableDialog extends StatefulWidget {
  final TableModel table;
  const _EditTableDialog({required this.table});

  @override
  State<_EditTableDialog> createState() => _EditTableDialogState();
}

class _EditTableDialogState extends State<_EditTableDialog> {
  late TextEditingController _numberController;
  late TextEditingController _capacityController;
  late TextEditingController _noteController;
  final _numberFocus = FocusNode();
  final _capacityFocus = FocusNode();
  final _noteFocus = FocusNode();
  late bool _isOccupied;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(text: widget.table.number.toString());
    _capacityController = TextEditingController(text: widget.table.capacity.toString());
    _noteController = TextEditingController(text: widget.table.note);
    _isOccupied = widget.table.isOccupied;
  }

  @override
  void dispose() {
    _numberController.dispose();
    _capacityController.dispose();
    _noteController.dispose();
    _numberFocus.dispose();
    _capacityFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.8 > 500 ? 500.0 : screenSize.width * 0.8;
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
                  '${'Edit Table'.tr()} ${widget.table.number}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                DoubleTapKeyboardListener(
                  focusNode: _numberFocus,
                  child: TextField(
                    controller: _numberController,
                    focusNode: _numberFocus,
                    decoration: InputDecoration(
                      labelText: 'Table Number'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 16),
                DoubleTapKeyboardListener(
                  focusNode: _capacityFocus,
                  child: TextField(
                    controller: _capacityController,
                    focusNode: _capacityFocus,
                    decoration: InputDecoration(
                      labelText: 'Capacity'.tr(),
                      border: const OutlineInputBorder(),
                      helperText: 'Number of seats at this table'.tr(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 16),
                DoubleTapKeyboardListener(
                  focusNode: _noteFocus,
                  child: TextField(
                    controller: _noteController,
                    focusNode: _noteFocus,
                    decoration: InputDecoration(
                      labelText: 'Note'.tr(),
                      border: const OutlineInputBorder(),
                      helperText: 'Optional information about this table'.tr(),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Table Status'.tr()),
                  subtitle: Text(_isOccupied ? 'Occupied'.tr() : 'Available'.tr()),
                  value: _isOccupied,
                  activeColor: Colors.red,
                  inactiveTrackColor: const Color.fromRGBO(76, 175, 80, 0.5),
                  onChanged: (value) {
                    setState(() {
                      _isOccupied = value;
                    });
                  },
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text('Cancel'.tr()),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      child: Text('Save'.tr()),
                      onPressed: () {
                        final number = int.tryParse(_numberController.text);
                        final capacity = int.tryParse(_capacityController.text);
                        
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
                          id: widget.table.id,
                          number: number,
                          capacity: capacity,
                          isOccupied: _isOccupied,
                          note: _noteController.text,
                        );
                        
                        Provider.of<TableProvider>(context, listen: false)
                          .updateTable(updatedTable);
                        
                        Navigator.of(context).pop();
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
  }
}
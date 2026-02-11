import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cafeapp/utils/app_localization.dart';
import '../providers/delivery_boy_provider.dart';
import '../models/delivery_boy.dart';
import '../utils/keyboard_utils.dart';

class DeliveryBoyManagementScreen extends StatefulWidget {
  const DeliveryBoyManagementScreen({super.key});

  @override
  State<DeliveryBoyManagementScreen> createState() => _DeliveryBoyManagementScreenState();
}

class _DeliveryBoyManagementScreenState extends State<DeliveryBoyManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DeliveryBoyProvider>(context, listen: false).loadDeliveryBoys();
    });
  }

  void _showAddEditDialog([DeliveryBoy? boy]) {
    showDialog(
      context: context,
      builder: (ctx) => _AddEditDeliveryBoyDialog(boy: boy),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Delivery Boy'.tr()),
        content: Text('Are you sure you want to delete this delivery boy?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Provider.of<DeliveryBoyProvider>(context, listen: false).deleteDeliveryBoy(id);
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Delivery Boy Management'.tr()),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.blue[800],
        child: const Icon(Icons.add),
      ),
      body: Consumer<DeliveryBoyProvider>(
        builder: (context, provider, child) {
          debugPrint('🏗️ Building Delivery Boy List: ${provider.deliveryBoys.length} items, isLoading: ${provider.isLoading}');
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (provider.deliveryBoys.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No delivery boys found'.tr(),
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.deliveryBoys.length,
            itemBuilder: (context, index) {
              final boy = provider.deliveryBoys[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      boy.name[0].toUpperCase(),
                      style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(boy.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(boy.phoneNumber),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddEditDialog(boy),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(boy.id!),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddEditDeliveryBoyDialog extends StatefulWidget {
  final DeliveryBoy? boy;
  const _AddEditDeliveryBoyDialog({this.boy});

  @override
  State<_AddEditDeliveryBoyDialog> createState() => _AddEditDeliveryBoyDialogState();
}

class _AddEditDeliveryBoyDialogState extends State<_AddEditDeliveryBoyDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.boy?.name ?? '');
    _phoneController = TextEditingController(text: widget.boy?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.boy == null ? 'Add Delivery Boy'.tr() : 'Edit Delivery Boy'.tr()),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DoubleTapKeyboardListener(
              focusNode: _nameFocus,
              child: TextFormField(
                controller: _nameController,
                focusNode: _nameFocus,
                decoration: InputDecoration(labelText: 'Name'.tr()),
                validator: (value) => value!.isEmpty ? 'Please enter name'.tr() : null,
              ),
            ),
            DoubleTapKeyboardListener(
              focusNode: _phoneFocus,
              child: TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                decoration: InputDecoration(labelText: 'Phone'.tr()),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Please enter phone'.tr() : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              try {
                final newBoy = DeliveryBoy(
                  id: widget.boy?.id,
                  name: _nameController.text,
                  phoneNumber: _phoneController.text,
                );
                
                final provider = Provider.of<DeliveryBoyProvider>(context, listen: false);
                
                if (widget.boy == null) {
                  await provider.addDeliveryBoy(newBoy);
                  if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delivery Boy added successfully'.tr()), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  await provider.updateDeliveryBoy(newBoy);
                  if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delivery Boy updated successfully'.tr()), backgroundColor: Colors.green),
                    );
                  }
                }
                
                if (context.mounted) Navigator.of(context).pop();
              } catch (e) {
                debugPrint('Error in Save Dialog: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${'Failed to save: '.tr()}$e'), backgroundColor: Colors.red),
                  );
                }
              }
            }
          },
          child: Text('Save'.tr()),
        ),
      ],
    );
  }
}

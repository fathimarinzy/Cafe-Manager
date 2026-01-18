import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cafeapp/utils/app_localization.dart';
import '../providers/delivery_boy_provider.dart';
import '../models/delivery_boy.dart';

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
    final nameController = TextEditingController(text: boy?.name ?? '');
    final phoneController = TextEditingController(text: boy?.phoneNumber ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(boy == null ? 'Add Delivery Boy'.tr() : 'Edit Delivery Boy'.tr()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'.tr()),
                validator: (value) => value!.isEmpty ? 'Please enter name'.tr() : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Phone'.tr()),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Please enter phone'.tr() : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final newBoy = DeliveryBoy(
                    id: boy?.id,
                    name: nameController.text,
                    phoneNumber: phoneController.text,
                  );
                  
                  final provider = Provider.of<DeliveryBoyProvider>(context, listen: false);
                  
                  if (boy == null) {
                    await provider.addDeliveryBoy(newBoy);
                    if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Delivery Boy added successfully'.tr()), backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    await provider.updateDeliveryBoy(newBoy);
                    if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Delivery Boy updated successfully'.tr()), backgroundColor: Colors.green),
                      );
                    }
                  }
                  
                  if (context.mounted) Navigator.of(ctx).pop();
                } catch (e) {
                  debugPrint('Error in Save Dialog: $e');
                  if (mounted) {
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
      ),
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

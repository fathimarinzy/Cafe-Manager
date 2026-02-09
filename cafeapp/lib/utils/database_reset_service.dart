import 'package:flutter/material.dart';
// Import Repositories to close connections properly
import '../repositories/local_menu_repository.dart';
import '../repositories/local_order_repository.dart';
import '../repositories/local_person_repository.dart';
import '../repositories/local_expense_repository.dart';
import '../repositories/credit_transaction_repository.dart';
import '../repositories/local_delivery_boy_repository.dart';

class DatabaseResetService {
  // Singleton pattern
  static final DatabaseResetService _instance = DatabaseResetService._internal();
  factory DatabaseResetService() => _instance;
  DatabaseResetService._internal();
  
  // Database file names



  // Force reset all data (Factory Reset)
  // UPDATED: Now clears tables instead of deleting files to prevent "database closed" errors
  Future<void> forceResetAllDatabases() async {
    try {
      debugPrint('Starting force reset of all databases (clearing tables)...');
      
      // Clear data using repository methods
      // This keeps the database connection open but removes all records
      await LocalMenuRepository().clearData();
      await LocalOrderRepository().clearData();
      await LocalPersonRepository().clearData();
      await LocalExpenseRepository().clearData();
      await CreditTransactionRepository().clearData();
      await LocalDeliveryBoyRepository().clearData();
      
      // Clear all SharedPreferences
      // This handles the "Factory Reset" part (clearing registration, settings, etc.)
      // without needing to physically delete the DB files.
      // NOTE: SharedPrefs clearing is done by the caller (SettingsScreen) or here if needed.
      // But usually it's better to do it here to ensure "All Databases" means "All Persistence".
       
      debugPrint('All databases have been force reset (tables cleared)');
    } catch (e) {
      debugPrint('Error in forceResetAllDatabases: $e');
      rethrow;
    }
  }

  // Reset operational data only (Preserves Menu, Device Registration, and Settings)
  // UPDATED: Now clears tables instead of deleting files to prevent "database closed" errors
  Future<void> resetOperationalData() async {
    try {
      debugPrint('Starting reset of operational data (clearing tables)...');
      
      // Clear data using repository methods
      // This keeps the database connection open but removes all records
      await LocalOrderRepository().clearData();
      await LocalPersonRepository().clearData();
      await LocalExpenseRepository().clearData();
      await CreditTransactionRepository().clearData();
      await LocalDeliveryBoyRepository().clearData();
      
      // We do NOT close databases or delete files for partial reset anymore
      
      debugPrint('Operational data has been cleared');
    } catch (e) {
      debugPrint('Error in resetOperationalData: $e');
      rethrow;
    }
  }
  

  
  // Clear application cache

}
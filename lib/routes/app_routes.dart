import 'package:flutter/material.dart';

import '../presentation/activity_log_screen/activity_log_screen.dart';
import '../presentation/add_edit_item_screen/add_edit_item_screen.dart';
import '../presentation/bulk_stock_screen/bulk_stock_screen.dart';
import '../presentation/categories_screen/categories_screen.dart';
import '../presentation/create_store_screen/create_store_screen.dart';
import '../presentation/inventory_screen/inventory_screen.dart';
import '../presentation/select_store_screen/select_store_screen.dart';
import '../presentation/sign_up_login_screen/sign_up_login_screen.dart';
import '../presentation/stock_session_history_screen/stock_session_history_screen.dart';
import '../presentation/stock_session_success_screen/stock_session_success_screen.dart';
import '../presentation/user_management_screen/user_management_screen.dart';
import '../presentation/settings_screen/settings_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String signUpLoginScreen = '/sign-up-login-screen';
  static const String createStoreScreen = '/create-store-screen';
  static const String selectStoreScreen = '/select-store-screen';
  static const String inventoryScreen = '/inventory-screen';
  static const String addEditItemScreen = '/add-edit-item-screen';
  static const String activityLogScreen = '/activity-log-screen';
  static const String categoriesScreen = '/categories-screen';
  static const String userManagementScreen = '/user-management-screen';
  static const String settingsScreen = '/settings-screen';
  static const String bulkStockScreen = '/bulk-stock-screen';
  static const String stockSessionSuccess = '/stock-session-success';
  static const String stockSessionHistory = '/stock-session-history';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SignUpLoginScreen(),
    signUpLoginScreen: (context) => const SignUpLoginScreen(),
    createStoreScreen: (context) => const CreateStoreScreen(),
    selectStoreScreen: (context) => const SelectStoreScreen(),
    inventoryScreen: (context) => const InventoryScreen(),
    addEditItemScreen: (context) => const AddEditItemScreen(),
    activityLogScreen: (context) => const ActivityLogScreen(),
    categoriesScreen: (context) => const CategoriesScreen(),
    userManagementScreen: (context) => const UserManagementScreen(),
    settingsScreen: (context) => const SettingsScreen(),
    bulkStockScreen: (context) => const BulkStockScreen(),
    stockSessionSuccess: (context) => const StockSessionSuccessScreen(),
    stockSessionHistory: (context) => const StockSessionHistoryScreen(),
  };
}

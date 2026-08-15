import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized currency / number formatting configuration.
///
/// This is a static holder rather than a provider-only value because the PDF
/// (`BillService`) and printing (`ThermalPrinterService`) paths have no
/// `BuildContext` and cannot reach `SettingsProvider`. Those services already
/// read raw preferences directly, so a static keeps one source of truth for
/// both the UI and the print paths.
///
/// `SettingsProvider` mirrors this value for widgets that need to rebuild on
/// change; every write must go through both.
class CurrencyFormat {
  static const String prefsKey = 'currency_decimal_places';

  /// Matches the decimal count the app used before this setting existed, so
  /// upgrading installs look unchanged until the owner picks something else.
  static const int defaultDecimals = 3;

  static const List<int> allowedDecimals = [0, 1, 2, 3];

  static int _decimals = defaultDecimals;
  static NumberFormat _grouped =
      NumberFormat.currency(symbol: '', decimalDigits: defaultDecimals);

  static int get decimals => _decimals;

  /// Grouped style — "1,234.500". Used where the app already displayed money
  /// through `NumberFormat.currency`.
  static NumberFormat get numberFormat => _grouped;

  /// Plain style — "1234.500". Used where the app already displayed money
  /// through `toStringAsFixed`.
  static String money(num value) => value.toStringAsFixed(_decimals);

  static String grouped(num value) => _grouped.format(value);

  /// Applies a decimal count in memory and rebuilds the cached NumberFormat.
  /// Values outside [allowedDecimals] fall back to the default.
  static void applyDecimals(int value) {
    _decimals = allowedDecimals.contains(value) ? value : defaultDecimals;
    _grouped = NumberFormat.currency(symbol: '', decimalDigits: _decimals);
  }

  /// Loads the persisted value. Called once at startup, before runApp.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      applyDecimals(prefs.getInt(prefsKey) ?? defaultDecimals);
    } catch (e) {
      applyDecimals(defaultDecimals);
    }
  }

  static Future<void> setDecimals(int value) async {
    applyDecimals(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsKey, _decimals);
  }
}

extension MoneyFormatting on num {
  /// Formats this value as a plain money string using the configured number
  /// of decimal places.
  String toMoney() => CurrencyFormat.money(this);
}

import 'package:intl/intl.dart';

class CurrencyUtil {
  static String format(double amount, String currencyCode) {
    switch (currencyCode) {
      case 'LAK':
        final f = NumberFormat('#,##0', 'lo');
        return '₭${f.format(amount.round())}';
      case 'THB':
        final f = NumberFormat('#,##0.00', 'th');
        return '฿${f.format(amount)}';
      case 'USD':
        final f = NumberFormat('#,##0.00', 'en');
        return '\$${f.format(amount)}';
      default:
        return amount.toStringAsFixed(2);
    }
  }

  static String symbol(String currencyCode) {
    switch (currencyCode) {
      case 'LAK': return '₭';
      case 'THB': return '฿';
      case 'USD': return '\$';
      default: return currencyCode;
    }
  }

  static int decimals(String currencyCode) {
    switch (currencyCode) {
      case 'LAK': return 0;
      case 'THB': return 2;
      case 'USD': return 2;
      default: return 2;
    }
  }

  /// Quick amounts for payment screen (based on currency)
  static List<double> quickAmounts(double total, String currencyCode) {
    switch (currencyCode) {
      case 'LAK':
        return <double>[
          _roundUp(total, 1000),
          _roundUp(total, 5000),
          _roundUp(total, 10000),
          _roundUp(total, 50000),
          100000.0,
          200000.0,
        ].toSet().toList()..sort();
      case 'THB':
        return <double>[
          _roundUp(total, 10),
          _roundUp(total, 20),
          _roundUp(total, 100),
          500.0,
          1000.0,
        ].toSet().toList()..sort();
      case 'USD':
        return <double>[
          _roundUp(total, 1),
          _roundUp(total, 5),
          _roundUp(total, 10),
          20.0,
          50.0,
          100.0,
        ].toSet().toList()..sort();
      default:
        return [total];
    }
  }

  static double _roundUp(double value, double step) {
    return (value / step).ceil() * step;
  }
}

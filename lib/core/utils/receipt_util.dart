import 'package:esc_pos_utils/esc_pos_utils.dart';

class ReceiptUtil {
  static String buildReceiptText({
    required Map<String, dynamic> settings,
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> saleItems,
    required String currency,
  }) {
    final buffer = StringBuffer();
    final header = (settings['receiptHeader'] as String?)?.trim();
    final footer = (settings['receiptFooter'] as String?)?.trim();

    buffer.writeln(header?.isNotEmpty == true ? header : settings['storeName']);
    buffer.writeln(
      [
        if ((settings['storeAddress'] as String?)?.isNotEmpty == true)
          settings['storeAddress'],
        if ((settings['storePhone'] as String?)?.isNotEmpty == true)
          settings['storePhone'],
      ].join(' | '),
    );
    buffer.writeln('Receipt #${sale['receiptNumber']}');
    buffer.writeln('Date ${sale['createdAt']}');
    buffer.writeln('--------------------------------');
    for (final item in saleItems) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
      final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
      final totalPrice = (item['totalPrice'] as num?)?.toDouble() ?? 0;
      buffer.writeln(item['itemName']);
      buffer.writeln(
        '${_formatQty(qty)} x ${_formatMoney(unitPrice, currency)}   ${_formatMoney(totalPrice, currency)}',
      );
    }
    buffer.writeln('--------------------------------');
    buffer.writeln(
      'Subtotal   ${_formatMoney((sale['subtotal'] as num?)?.toDouble() ?? 0, currency)}',
    );
    if (((sale['discountAmount'] as num?)?.toDouble() ?? 0) > 0) {
      buffer.writeln(
        'Discount   -${_formatMoney((sale['discountAmount'] as num?)?.toDouble() ?? 0, currency)}',
      );
    }
    if (((sale['taxAmount'] as num?)?.toDouble() ?? 0) > 0) {
      buffer.writeln(
        'Tax        ${_formatMoney((sale['taxAmount'] as num?)?.toDouble() ?? 0, currency)}',
      );
    }
    buffer.writeln(
      'TOTAL      ${_formatMoney((sale['totalAmount'] as num?)?.toDouble() ?? 0, currency)}',
    );
    buffer.writeln(
      'Paid       ${_formatMoney((sale['amountPaid'] as num?)?.toDouble() ?? 0, currency)}',
    );
    buffer.writeln(
      'Change     ${_formatMoney((sale['changeAmount'] as num?)?.toDouble() ?? 0, currency)}',
    );
    buffer.writeln('Payment    ${sale['paymentMethod']}');
    if (footer?.isNotEmpty == true) {
      buffer.writeln('--------------------------------');
      buffer.writeln(footer);
    }
    return buffer.toString().trim();
  }

  static Future<List<int>> buildReceiptBytes({
    required Map<String, dynamic> settings,
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> saleItems,
    required String currency,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];
    final storeName =
        (settings['receiptHeader'] as String?)?.trim().isNotEmpty == true
            ? (settings['receiptHeader'] as String).trim()
            : (settings['storeName'] as String? ?? 'Kinsaep POS');

    bytes.addAll(generator.reset());
    bytes.addAll(
      generator.text(
        storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    if ((settings['storeAddress'] as String?)?.isNotEmpty == true) {
      bytes.addAll(
        generator.text(
          settings['storeAddress'] as String,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if ((settings['storePhone'] as String?)?.isNotEmpty == true) {
      bytes.addAll(
        generator.text(
          settings['storePhone'] as String,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('Receipt #${sale['receiptNumber']}'));
    bytes.addAll(generator.text('Date ${sale['createdAt']}'));
    bytes.addAll(generator.hr());
    for (final item in saleItems) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
      final totalPrice = (item['totalPrice'] as num?)?.toDouble() ?? 0;
      bytes.addAll(
        generator.row([
          PosColumn(text: item['itemName'] as String? ?? '-', width: 7),
          PosColumn(
            text: _formatQty(qty),
            width: 2,
            styles: const PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            text: _formatMoney(totalPrice, currency),
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: _formatMoney(
            (sale['totalAmount'] as num?)?.toDouble() ?? 0,
            currency,
          ),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );
    bytes.addAll(
      generator.text(
        'Paid ${_formatMoney((sale['amountPaid'] as num?)?.toDouble() ?? 0, currency)}',
      ),
    );
    bytes.addAll(
      generator.text(
        'Change ${_formatMoney((sale['changeAmount'] as num?)?.toDouble() ?? 0, currency)}',
      ),
    );
    if ((settings['receiptFooter'] as String?)?.isNotEmpty == true) {
      bytes.addAll(generator.feed(1));
      bytes.addAll(
        generator.text(
          settings['receiptFooter'] as String,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    bytes.addAll(generator.feed(3));
    return bytes;
  }

  static String buildKitchenText({
    required String storeName,
    required Map<String, dynamic> ticket,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(storeName);
    buffer.writeln('Kitchen Ticket ${ticket['id']}');
    buffer.writeln('Status ${ticket['status']}');
    buffer.writeln('-----------------------------');
    final items =
        (ticket['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    for (final item in items) {
      buffer.writeln(
        '${_formatQty((item['quantity'] as num?)?.toDouble() ?? 1)} x ${item['itemName']}',
      );
      if ((item['note'] as String?)?.isNotEmpty == true) {
        buffer.writeln('  note: ${item['note']}');
      }
    }
    return buffer.toString().trim();
  }

  static String _formatQty(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  static String _formatMoney(double value, String currency) {
    return '$currency ${value.toStringAsFixed(2)}';
  }
}

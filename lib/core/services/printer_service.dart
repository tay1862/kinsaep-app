import 'dart:io';

import 'package:kinsaep_pos/core/utils/receipt_util.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:share_plus/share_plus.dart';

class PrinterService {
  static Future<List<BluetoothInfo>> getPairedPrinters() async {
    final hasPermission =
        await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!hasPermission) {
      return [];
    }
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      return [];
    }
    return PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<bool> connect(String macAddress) async {
    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  static Future<bool> disconnect() async {
    return PrintBluetoothThermal.disconnect;
  }

  static Future<bool> printReceipt({
    required String? printerMac,
    required Map<String, dynamic> settings,
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> saleItems,
    required String currency,
  }) async {
    if (printerMac == null || printerMac.isEmpty) {
      throw Exception('Select a printer before printing.');
    }

    if (Platform.isIOS) {
      await shareReceipt(
        settings: settings,
        sale: sale,
        saleItems: saleItems,
        currency: currency,
      );
      return true;
    }

    final connected = await PrintBluetoothThermal.connectionStatus;
    final ready = connected || await connect(printerMac);
    if (!ready) {
      throw Exception('Unable to connect to the selected printer.');
    }

    final bytes = await ReceiptUtil.buildReceiptBytes(
      settings: settings,
      sale: sale,
      saleItems: saleItems,
      currency: currency,
    );
    final success = await PrintBluetoothThermal.writeBytes(bytes);
    if (!success) {
      throw Exception('Printer rejected the receipt bytes.');
    }
    return true;
  }

  static Future<void> shareReceipt({
    required Map<String, dynamic> settings,
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> saleItems,
    required String currency,
  }) async {
    final text = ReceiptUtil.buildReceiptText(
      settings: settings,
      sale: sale,
      saleItems: saleItems,
      currency: currency,
    );
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Receipt #${sale['receiptNumber']}'),
    );
  }
}

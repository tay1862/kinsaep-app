import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/services/printer_service.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PrinterScreen extends ConsumerStatefulWidget {
  const PrinterScreen({super.key});

  @override
  ConsumerState<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends ConsumerState<PrinterScreen> {
  List<BluetoothInfo> _printers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() => _loading = true);
    final printers = await PrinterService.getPairedPrinters();
    if (!mounted) {
      return;
    }
    setState(() {
      _printers = printers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storeSettingsProvider);
    final salesAsync = ref.watch(salesHistoryProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Printer',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _loadPrinters,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: settingsAsync.when(
        data:
            (settings) => salesAsync.when(
              data:
                  (sales) => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: KinsaepTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Receipt Printer',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (settings['printerName'] as String?)
                                          ?.isNotEmpty ==
                                      true
                                  ? settings['printerName'] as String
                                  : 'No printer selected',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (settings['printerMac'] as String?)?.isNotEmpty ==
                                      true
                                  ? settings['printerMac'] as String
                                  : 'Choose a paired printer below',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: KinsaepTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _printTest(settings, sales),
                                icon: const Icon(Icons.print_rounded),
                                label: const Text('Test Print'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await PrinterService.disconnect();
                                  _showMessage('Printer disconnected.');
                                },
                                icon: const Icon(Icons.link_off_rounded),
                                label: const Text('Disconnect'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_printers.isEmpty)
                        _emptyPanel(
                          'No paired printer found. Pair the printer from system Bluetooth settings first.',
                        )
                      else
                        ..._printers.map(
                          (printer) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: KinsaepTheme.cardShadow,
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.print_rounded,
                                color: KinsaepTheme.primary,
                              ),
                              title: Text(
                                printer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(printer.macAdress),
                              trailing:
                                  settings['printerMac'] == printer.macAdress
                                      ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: KinsaepTheme.accent,
                                      )
                                      : null,
                              onTap: () async {
                                await DatabaseHelper.instance.updateSettings({
                                  'printerName': printer.name,
                                  'printerMac': printer.macAdress,
                                });
                                ref.invalidate(storeSettingsProvider);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _printTest(
    Map<String, dynamic> settings,
    List<Map<String, dynamic>> sales,
  ) async {
    final testSale =
        sales.isNotEmpty
            ? sales.first
            : <String, dynamic>{
              'receiptNumber': 'TEST-001',
              'subtotal': 12.50,
              'discountAmount': 0,
              'taxAmount': 0,
              'totalAmount': 12.50,
              'amountPaid': 20.00,
              'changeAmount': 7.50,
              'paymentMethod': 'cash',
              'createdAt': DateTime.now().toIso8601String(),
            };

    final testItems =
        sales.isNotEmpty
            ? await DatabaseHelper.instance.getSaleItems(
              sales.first['id'] as String,
            )
            : <Map<String, dynamic>>[
              {
                'itemName': 'Printer Test Item',
                'quantity': 1,
                'unitPrice': 12.50,
                'totalPrice': 12.50,
              },
            ];

    try {
      await PrinterService.printReceipt(
        printerMac: settings['printerMac'] as String?,
        settings: settings,
        sale: testSale,
        saleItems: testItems,
        currency: settings['currency'] as String? ?? 'LAK',
      );
      _showMessage('Printer test sent.');
    } catch (error) {
      _showMessage('$error');
    }
  }

  Widget _emptyPanel(String text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: KinsaepTheme.cardShadow,
      ),
      child: Text(
        text,
        style: const TextStyle(color: KinsaepTheme.textSecondary),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

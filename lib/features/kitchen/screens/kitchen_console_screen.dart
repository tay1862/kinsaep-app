import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/app/theme.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';
import 'package:kinsaep_pos/core/network/api_client.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';
import 'package:kinsaep_pos/core/network/sync_service.dart';
import 'package:kinsaep_pos/core/providers/app_providers.dart';
import 'package:kinsaep_pos/core/services/store_realtime_client.dart';

class KitchenConsoleScreen extends ConsumerStatefulWidget {
  const KitchenConsoleScreen({super.key});

  @override
  ConsumerState<KitchenConsoleScreen> createState() =>
      _KitchenConsoleScreenState();
}

class _KitchenConsoleScreenState extends ConsumerState<KitchenConsoleScreen> {
  final StoreRealtimeClient _realtimeClient = StoreRealtimeClient();
  String _stationFilter = 'ALL';
  String? _realtimeKey;

  @override
  void dispose() {
    _realtimeClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(kitchenTicketsProvider);
    final stationsAsync = ref.watch(kitchenStationsProvider);
    final settingsAsync = ref.watch(storeSettingsProvider);

    return Scaffold(
      backgroundColor: KinsaepTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Kitchen Console',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshKitchen,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: settingsAsync.when(
        data: (settings) {
          _bindRealtime(settings);
          return stationsAsync.when(
            data:
                (stations) => ticketsAsync.when(
                  data: (tickets) {
                    final stationById = {
                      for (final station in stations)
                        station['id'] as String: station,
                    };
                    final filteredTickets =
                        tickets.where((ticket) {
                          if (_stationFilter == 'ALL') {
                            return true;
                          }
                          final items =
                              (ticket['items'] as List<dynamic>? ?? [])
                                  .cast<Map<String, dynamic>>();
                          return items.any((item) {
                            final station = stationById[item['stationId']];
                            return station?['type'] == _stationFilter;
                          });
                        }).toList();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _filterChip('ALL'),
                            _filterChip('HOT'),
                            _filterChip('COLD'),
                            _filterChip('DRINK'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (filteredTickets.isEmpty)
                          _emptyPanel('No kitchen tickets for $_stationFilter.')
                        else
                          ...filteredTickets.map(
                            (ticket) => _buildTicketCard(
                              settings: settings,
                              ticket: ticket,
                              stationById: stationById,
                            ),
                          ),
                      ],
                    );
                  },
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Error: $error')),
                ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> _bindRealtime(Map<String, dynamic> settings) async {
    final remoteStoreId = settings['remoteStoreId'] as String?;
    final wsUrl = await ApiClient.getWebSocketUrl();
    if (remoteStoreId == null || remoteStoreId.isEmpty || wsUrl == null) {
      return;
    }
    final key = '$wsUrl::$remoteStoreId';
    if (_realtimeKey == key) {
      return;
    }
    _realtimeKey = key;
    await _realtimeClient.connect(wsUrl: wsUrl, storeId: remoteStoreId);
    _realtimeClient.events.listen((event) async {
      if (event.event.startsWith('kitchen.')) {
        await _refreshKitchen();
      }
    });
  }

  Widget _buildTicketCard({
    required Map<String, dynamic> settings,
    required Map<String, dynamic> ticket,
    required Map<String, Map<String, dynamic>> stationById,
  }) {
    final items =
        (ticket['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: KinsaepTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  ticket['saleId'] as String? ?? ticket['id'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                _statusBadge(ticket['status'] as String? ?? 'NEW'),
              ],
            ),
            if ((ticket['note'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                ticket['note'] as String,
                style: const TextStyle(color: KinsaepTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['quantity']}x',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['itemName'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            stationById[item['stationId']]?['type']
                                    as String? ??
                                'UNASSIGNED',
                            style: const TextStyle(
                              color: KinsaepTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusButton(settings, ticket, 'NEW'),
                _statusButton(settings, ticket, 'PREPARING'),
                _statusButton(settings, ticket, 'READY'),
                _statusButton(settings, ticket, 'SERVED'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(
    Map<String, dynamic> settings,
    Map<String, dynamic> ticket,
    String status,
  ) {
    final current = ticket['status'] == status;
    return OutlinedButton(
      onPressed:
          current ? null : () => _updateTicketStatus(settings, ticket, status),
      style: OutlinedButton.styleFrom(
        foregroundColor: current ? Colors.white : KinsaepTheme.primary,
        backgroundColor: current ? KinsaepTheme.primary : null,
      ),
      child: Text(status),
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'READY' => KinsaepTheme.accent,
      'PREPARING' => KinsaepTheme.warning,
      'SERVED' => Colors.grey,
      _ => KinsaepTheme.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _filterChip(String value) {
    final selected = _stationFilter == value;
    return ChoiceChip(
      label: Text(value),
      selected: selected,
      onSelected: (_) => setState(() => _stationFilter = value),
    );
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

  Future<void> _updateTicketStatus(
    Map<String, dynamic> settings,
    Map<String, dynamic> ticket,
    String status,
  ) async {
    final ticketId = ticket['id'] as String;
    await DatabaseHelper.instance.updateKitchenTicketStatus(ticketId, status);
    if (await _canWriteCloud(settings)) {
      final response = await ApiClient.patch('/kitchen/tickets/$ticketId', {
        'status': status,
      });
      if (response.statusCode != 200) {
        _showMessage('Failed to update kitchen ticket on server.');
      }
    }
    ref.invalidate(kitchenTicketsProvider);
  }

  Future<void> _refreshKitchen() async {
    try {
      final settings = await ref.read(storeSettingsProvider.future);
      if (await _canWriteCloud(settings)) {
        await SyncService.pullData(scopes: const ['kitchen']);
      }
      ref.invalidate(kitchenTicketsProvider);
      ref.invalidate(kitchenStationsProvider);
    } catch (error) {
      _showMessage('$error');
    }
  }

  static Future<bool> _canWriteCloud(Map<String, dynamic> settings) async {
    final hasSession = await ApiClient.hasSession();
    return hasSession &&
        ((settings['serverUrl'] as String?)?.isNotEmpty ?? false) &&
        (settings['syncEnabled'] == 1) &&
        ((settings['subscriptionStatus'] as String?) ==
            CloudSubscriptionStatus.active);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class StoreRealtimeEvent {
  final String event;
  final Map<String, dynamic> payload;

  const StoreRealtimeEvent({required this.event, required this.payload});
}

class StoreRealtimeClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _controller = StreamController<StoreRealtimeEvent>.broadcast();

  Stream<StoreRealtimeEvent> get events => _controller.stream;

  Future<void> connect({
    required String wsUrl,
    required String storeId,
    String? role,
  }) async {
    await disconnect();
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel!.sink.add(
      jsonEncode({
        'type': 'subscribe',
        'storeId': storeId,
        if (role != null) 'role': role,
      }),
    );
    _subscription = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          _controller.add(
            StoreRealtimeEvent(
              event: data['event'] as String? ?? 'unknown',
              payload:
                  (data['payload'] as Map?)?.cast<String, dynamic>() ??
                  const <String, dynamic>{},
            ),
          );
        } catch (_) {
          // Ignore malformed realtime payloads.
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}

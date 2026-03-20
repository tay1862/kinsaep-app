import 'package:flutter/services.dart';

class VendorScanEvent {
  final String code;
  final String source;

  const VendorScanEvent({required this.code, required this.source});
}

class VendorScannerService {
  static const EventChannel _channel = EventChannel(
    'com.kinsaep.kinsaep_pos/scanner_events',
  );

  static Stream<VendorScanEvent> get events {
    return _channel
        .receiveBroadcastStream()
        .map((event) {
          final payload = (event as Map).cast<dynamic, dynamic>();
          return VendorScanEvent(
            code: payload['code']?.toString() ?? '',
            source: payload['source']?.toString() ?? 'unknown',
          );
        })
        .where((event) => event.code.isNotEmpty);
  }
}

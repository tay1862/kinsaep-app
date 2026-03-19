import 'dart:convert';

import 'package:crypto/crypto.dart';

class PinSecurity {
  static const String _sha256Prefix = 'sha256:';

  static String hashPin(String pin) {
    final digest = sha256.convert(utf8.encode(pin));
    return '$_sha256Prefix${digest.toString()}';
  }

  static bool isHashed(String value) {
    return value.startsWith(_sha256Prefix);
  }

  static bool needsMigration(String value) {
    return value.isNotEmpty && !isHashed(value);
  }

  static bool matches(String pin, String storedValue) {
    if (isHashed(storedValue)) {
      return hashPin(pin) == storedValue;
    }

    return storedValue == pin;
  }
}

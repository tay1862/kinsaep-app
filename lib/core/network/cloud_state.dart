class CloudMode {
  static const String offlineOnly = 'OFFLINE_ONLY';
  static const String active = 'CLOUD_ACTIVE';
  static const String blocked = 'CLOUD_BLOCKED';
}

class CloudSubscriptionStatus {
  static const String none = 'NONE';
  static const String active = 'ACTIVE';
  static const String blocked = 'BLOCKED';
  static const String expired = 'EXPIRED';
}

class CloudAccessMode {
  static const String offlineOnly = 'OFFLINE_ONLY';
  static const String active = 'ACTIVE';
  static const String blocked = 'BLOCKED';
  static const String expired = 'EXPIRED';
}

class SyncProfileState {
  static const String off = 'OFF';
  static const String light = 'LIGHT';
  static const String full = 'FULL';
}

class DeviceTypeState {
  static const String pos = 'POS';
  static const String kitchen = 'KITCHEN';
  static const String manager = 'MANAGER';
}

class ScannerModeState {
  static const String auto = 'AUTO';
  static const String camera = 'CAMERA';
  static const String hid = 'HID';
  static const String sunmi = 'SUNMI';
  static const String zebra = 'ZEBRA';
}

class SyncJobState {
  static const String idle = 'IDLE';
  static const String queued = 'QUEUED';
  static const String running = 'RUNNING';
  static const String succeeded = 'SUCCEEDED';
  static const String failed = 'FAILED';
}

class SyncDirectionState {
  static const String push = 'PUSH';
  static const String pull = 'PULL';
}

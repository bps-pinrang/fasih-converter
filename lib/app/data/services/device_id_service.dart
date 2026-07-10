import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kDeviceIdKey = 'fasih_device_id';

@singleton
class DeviceIdService {
  final SharedPreferences _prefs;

  DeviceIdService(this._prefs);

  String get deviceId {
    final existing = _prefs.getString(_kDeviceIdKey);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    _prefs.setString(_kDeviceIdKey, id);
    return id;
  }
}

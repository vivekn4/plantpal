import 'package:battery_plus/battery_plus.dart';

/// Battery level as a real state: a percentage, or null for unknown.
/// Web without the Battery API is null — never a made-up number.
class BatteryService {
  BatteryService({Battery? battery}) : _battery = battery ?? Battery();

  final Battery _battery;

  Future<int?> level() async {
    try {
      final value = await _battery.batteryLevel;
      if (value < 0 || value > 100) return null;
      return value;
    } catch (_) {
      return null;
    }
  }
}

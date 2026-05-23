import 'package:flutter/foundation.dart';

/// Service that determines day/night based on device local time.
///
/// Daytime is defined as 06:00–18:00 local time.
/// The lux value is simulated based on the time of day.
class LightSensorService {
  double _currentLux = 500.0;

  double get currentLux => _currentLux;

  /// Returns `true` if the current local time is between 06:00 and 18:00.
  static bool isDaytime() {
    final hour = DateTime.now().hour;
    return hour >= 6 && hour < 18;
  }

  /// Auto-detect lux from time of day.
  /// Daytime → 500 lux, Night → 10 lux.
  void start() {
    _currentLux = isDaytime() ? 500.0 : 10.0;
    debugPrint('LightSensor: auto-detected ${isDaytime() ? "daytime" : "night"} ($_currentLux lux)');
  }

  /// Manually override lux value.
  void setManualLux(double lux) {
    _currentLux = lux;
  }

  void dispose() {
    // Nothing to clean up.
  }
}

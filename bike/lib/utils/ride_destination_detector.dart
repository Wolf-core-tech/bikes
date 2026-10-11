import 'dart:math' as math;

class RideDestinationDetector {
  double? _latitude;
  double? _longitude;
  int _consecutiveFixes = 0;
  bool _reached = false;
  DateTime? _lastFixTimestamp;

  void beginRide() {
    _latitude = null;
    _longitude = null;
    _consecutiveFixes = 0;
    _reached = false;
    _lastFixTimestamp = null;
  }

  void setDestination(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
    _consecutiveFixes = 0;
    _lastFixTimestamp = null;
  }

  void clearDestination() {
    _latitude = null;
    _longitude = null;
    _consecutiveFixes = 0;
    _lastFixTimestamp = null;
  }

  bool recordFix({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required double speedMetersPerSecond,
    required DateTime timestamp,
    required DateTime now,
  }) {
    final targetLatitude = _latitude;
    final targetLongitude = _longitude;
    if (_reached || targetLatitude == null || targetLongitude == null) {
      return false;
    }
    final fixAge = now.difference(timestamp).inSeconds.abs();
    final validFix =
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        accuracyMeters > 0 &&
        accuracyMeters <= 35 &&
        speedMetersPerSecond >= 0 &&
        speedMetersPerSecond <= 15 &&
        fixAge <= 20 &&
        (_lastFixTimestamp == null || timestamp.isAfter(_lastFixTimestamp!));
    if (!validFix) {
      _consecutiveFixes = 0;
      _lastFixTimestamp = null;
      return false;
    }

    final distanceMeters = _distanceMeters(
      latitude,
      longitude,
      targetLatitude,
      targetLongitude,
    );
    final threshold = math.max(35.0, math.min(80.0, accuracyMeters * 1.5));
    if (distanceMeters > threshold) {
      _consecutiveFixes = 0;
      _lastFixTimestamp = null;
      return false;
    }
    _lastFixTimestamp = timestamp;
    _consecutiveFixes++;
    if (_consecutiveFixes < 3) return false;
    _reached = true;
    return true;
  }

  double _distanceMeters(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final latitudeDelta = _radians(secondLatitude - firstLatitude);
    final longitudeDelta = _radians(secondLongitude - firstLongitude);
    final a = math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(_radians(firstLatitude)) *
            math.cos(_radians(secondLatitude)) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:bikers/utils/ride_destination_detector.dart';

void main() {
  late RideDestinationDetector detector;
  final start = DateTime.utc(2026, 10, 11, 10);

  setUp(() {
    detector = RideDestinationDetector()..beginRide();
    detector.setDestination(12.9716, 77.5946);
  });

  Map<String, Object> fix({
    int seconds = 1,
    double accuracy = 8,
    double speed = 0,
    double latitude = 12.9716,
    double longitude = 77.5946,
  }) => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracy,
    'speedMetersPerSecond': speed,
    'timestamp': start.add(Duration(seconds: seconds)),
    'now': start.add(Duration(seconds: seconds)),
  };

  bool record(Map<String, Object> values) => detector.recordFix(
    latitude: values['latitude']! as double,
    longitude: values['longitude']! as double,
    accuracyMeters: values['accuracyMeters']! as double,
    speedMetersPerSecond: values['speedMetersPerSecond']! as double,
    timestamp: values['timestamp']! as DateTime,
    now: values['now']! as DateTime,
  );

  test('requires three fresh, accurate fixes and emits only once', () {
    expect(record(fix(seconds: 1)), isFalse);
    expect(record(fix(seconds: 2)), isFalse);
    expect(record(fix(seconds: 3)), isTrue);
    expect(record(fix(seconds: 4)), isFalse);
  });

  test('rejects inaccurate, stale, fast, and out-of-geofence fixes', () {
    expect(record(fix(seconds: 1, accuracy: 36)), isFalse);
    expect(record(fix(seconds: 2, speed: 16)), isFalse);
    expect(record(fix(seconds: 3, latitude: 12.973)), isFalse);
    expect(
      detector.recordFix(
        latitude: 12.9716,
        longitude: 77.5946,
        accuracyMeters: 8,
        speedMetersPerSecond: 0,
        timestamp: start,
        now: start.add(const Duration(seconds: 25)),
      ),
      isFalse,
    );
    expect(record(fix(seconds: 4)), isFalse);
  });

  test('requires distinct GPS timestamps and resets for a new ride', () {
    expect(record(fix(seconds: 1)), isFalse);
    expect(record(fix(seconds: 1)), isFalse);
    expect(record(fix(seconds: 2)), isFalse);
    expect(record(fix(seconds: 3)), isFalse);
    expect(record(fix(seconds: 4)), isTrue);
    expect(record(fix(seconds: 5)), isFalse);
    detector.beginRide();
    detector.setDestination(12.9716, 77.5946);
    expect(record(fix(seconds: 6)), isFalse);
  });
}

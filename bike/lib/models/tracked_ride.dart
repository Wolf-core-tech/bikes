class RidePoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double speedMetersPerSecond;

  const RidePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.speedMetersPerSecond,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
    'speed': speedMetersPerSecond,
  };

  factory RidePoint.fromJson(Map<String, dynamic> json) => RidePoint(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
    speedMetersPerSecond: (json['speed'] as num?)?.toDouble() ?? 0,
  );
}

class TrackedRide {
  final String id;
  final String? rideName;
  final DateTime startTime;
  final DateTime endTime;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final double totalDistanceMeters;
  final double maximumSpeedMetersPerSecond;
  final double averageSpeedMetersPerSecond;
  final Duration totalDuration;
  final Duration stoppedDuration;
  final int stopCount;
  final List<RidePoint> points;

  const TrackedRide({
    required this.id,
    this.rideName,
    required this.startTime,
    required this.endTime,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.totalDistanceMeters,
    required this.maximumSpeedMetersPerSecond,
    required this.averageSpeedMetersPerSecond,
    required this.totalDuration,
    required this.stoppedDuration,
    required this.stopCount,
    required this.points,
  });

  double get distanceKm => totalDistanceMeters / 1000;
  double get averageSpeedKmh => averageSpeedMetersPerSecond * 3.6;
  double get maximumSpeedKmh => maximumSpeedMetersPerSecond * 3.6;

  Map<String, dynamic> toJson() => {
    'id': id,
    'rideName': rideName,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'startLatitude': startLatitude,
    'startLongitude': startLongitude,
    'endLatitude': endLatitude,
    'endLongitude': endLongitude,
    'totalDistanceMeters': totalDistanceMeters,
    'maximumSpeedMetersPerSecond': maximumSpeedMetersPerSecond,
    'averageSpeedMetersPerSecond': averageSpeedMetersPerSecond,
    'totalDurationSeconds': totalDuration.inSeconds,
    'stoppedDurationSeconds': stoppedDuration.inSeconds,
    'stopCount': stopCount,
    'points': points.map((point) => point.toJson()).toList(),
  };

  factory TrackedRide.fromJson(Map<String, dynamic> json) => TrackedRide(
    id: json['id'] as String,
    rideName: json['rideName'] as String?,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    startLatitude: (json['startLatitude'] as num).toDouble(),
    startLongitude: (json['startLongitude'] as num).toDouble(),
    endLatitude: (json['endLatitude'] as num).toDouble(),
    endLongitude: (json['endLongitude'] as num).toDouble(),
    totalDistanceMeters: (json['totalDistanceMeters'] as num).toDouble(),
    maximumSpeedMetersPerSecond: (json['maximumSpeedMetersPerSecond'] as num)
        .toDouble(),
    averageSpeedMetersPerSecond: (json['averageSpeedMetersPerSecond'] as num)
        .toDouble(),
    totalDuration: Duration(
      seconds: (json['totalDurationSeconds'] as num).toInt(),
    ),
    stoppedDuration: Duration(
      seconds: (json['stoppedDurationSeconds'] as num).toInt(),
    ),
    stopCount: (json['stopCount'] as num).toInt(),
    points: (json['points'] as List<dynamic>)
        .map((point) => RidePoint.fromJson(point as Map<String, dynamic>))
        .toList(),
  );
}

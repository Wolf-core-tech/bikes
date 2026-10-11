import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/tracked_ride.dart';
import '../services/ride_storage.dart';
import '../utils/ride_destination_detector.dart';

class RideTrackingProvider extends ChangeNotifier {
  final RideStorage _storage;
  final RideDestinationDetector _destinationDetector =
      RideDestinationDetector();
  final StreamController<Map<String, String?>> _destinationReachedController =
      StreamController<Map<String, String?>>.broadcast();
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  Timer? _durationTimer;
  final List<RidePoint> _routePoints = [];
  final List<TrackedRide> _completedRides = [];

  DateTime? _startTime;
  String? _rideName;
  DateTime? _stopStartedAt;
  double _distanceMeters = 0;
  double _maximumSpeed = 0;
  Duration _stoppedDuration = Duration.zero;
  int _stopCount = 0;
  Position? _currentPosition;
  double _compassHeading = 0.0;
  TrackedRide? _selectedRide;
  String? _errorMessage;
  bool _isLoadingHistory = true;
  bool _isTracking = false;
  String? _activeRideId;
  String? _destinationName;

  RideTrackingProvider({RideStorage? storage})
    : _storage = storage ?? RideStorage() {
    _loadHistory();
  }

  bool get isTracking => _isTracking;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get errorMessage => _errorMessage;
  Position? get currentPosition => _currentPosition;
  double get compassHeading => _compassHeading;
  List<RidePoint> get routePoints => List.unmodifiable(_routePoints);
  List<TrackedRide> get completedRides => List.unmodifiable(_completedRides);
  TrackedRide? get selectedRide => _selectedRide;
  double get distanceKm => _distanceMeters / 1000;
  double get currentSpeedKmh => (_currentPosition?.speed ?? 0) * 3.6;
  double get maximumSpeedKmh => _maximumSpeed * 3.6;
  Duration get rideDuration => _startTime == null
      ? Duration.zero
      : DateTime.now().difference(_startTime!);
  Duration get stoppedDuration =>
      _stoppedDuration +
      (_stopStartedAt == null
          ? Duration.zero
          : DateTime.now().difference(_stopStartedAt!));
  int get stopCount => _stopCount;
  Stream<Map<String, String?>> get destinationReachedEvents =>
      _destinationReachedController.stream;
  LatLng? get currentLatLng => _currentPosition == null
      ? null
      : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

  Future<bool> loadCurrentLocation() async {
    _errorMessage = null;
    if (!await Geolocator.isLocationServiceEnabled()) {
      _errorMessage =
          'Location services are disabled. Enable GPS and try again.';
      notifyListeners();
      return false;
    }

    _initCompass();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      _errorMessage = 'Location permission was denied.';
      notifyListeners();
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      _errorMessage =
          'Location permission is permanently denied. Enable it in Settings.';
      notifyListeners();
      return false;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage =
          'Unable to get a GPS location. Move outdoors and try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadHistory() async {
    try {
      _completedRides
        ..clear()
        ..addAll(await _storage.loadRides());
    } catch (_) {
      _errorMessage = 'Saved ride history could not be loaded.';
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<bool> startRide({String? rideName}) async {
    _errorMessage = null;
    if (!await Geolocator.isLocationServiceEnabled()) {
      _errorMessage =
          'Location services are disabled. Enable GPS and try again.';
      notifyListeners();
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      _errorMessage = 'Location permission was denied.';
      notifyListeners();
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      _errorMessage =
          'Location permission is permanently denied. Enable it in Settings.';
      notifyListeners();
      return false;
    }

    await _positionSubscription?.cancel();
    _durationTimer?.cancel();
    _initCompass();
    _routePoints.clear();
    _distanceMeters = 0;
    _maximumSpeed = 0;
    _stoppedDuration = Duration.zero;
    _stopStartedAt = null;
    _stopCount = 0;
    _startTime = DateTime.now();
    _activeRideId = _startTime!.microsecondsSinceEpoch.toString();
    _rideName = rideName?.trim();
    _destinationDetector.beginRide();
    _destinationName = null;
    _selectedRide = null;
    _isTracking = true;

    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _recordPosition(initialPosition);
      
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
      });

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen(
            _recordPosition,
            onError: (_) {
              _errorMessage = 'GPS updates are temporarily unavailable.';
              notifyListeners();
            },
          );
    } catch (_) {
      _isTracking = false;
      _startTime = null;
      _durationTimer?.cancel();
      _errorMessage =
          'Unable to get a GPS location. Move outdoors and try again.';
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  void _recordPosition(Position position) {
    final point = RidePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      speedMetersPerSecond: position.speed < 0 ? 0 : position.speed,
    );
    final previous = _routePoints.isEmpty ? null : _routePoints.last;
    if (previous != null) {
      _distanceMeters += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
    }
    _routePoints.add(point);
    _currentPosition = position;
    _checkDestination(position);
    _maximumSpeed = position.speed > _maximumSpeed
        ? position.speed
        : _maximumSpeed;

    final isStopped = point.speedMetersPerSecond < 1.0;
    if (isStopped && _stopStartedAt == null) {
      _stopStartedAt = point.timestamp;
      if (previous != null) _stopCount++;
    } else if (!isStopped && _stopStartedAt != null) {
      _stoppedDuration += point.timestamp.difference(_stopStartedAt!);
      _stopStartedAt = null;
    }
    notifyListeners();
  }

  void setRideDestination({
    required double latitude,
    required double longitude,
    required String? name,
  }) {
    if (!_isTracking) return;
    _destinationDetector.setDestination(latitude, longitude);
    _destinationName = name?.trim();
  }

  void clearRideDestination() {
    _destinationDetector.clearDestination();
    _destinationName = null;
  }

  void _checkDestination(Position position) {
    if (!_isTracking) return;
    final reached = _destinationDetector.recordFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      speedMetersPerSecond: position.speed,
      timestamp: position.timestamp,
      now: DateTime.now(),
    );
    if (!reached) return;
    final rideId = _activeRideId;
    if (rideId != null) {
      _destinationReachedController.add({
        'rideId': rideId,
        'destinationName': _destinationName,
      });
    }
  }

  Future<TrackedRide?> stopRide() async {
    if (!_isTracking || _startTime == null || _routePoints.isEmpty) return null;
    await _positionSubscription?.cancel();
    _durationTimer?.cancel();
    _positionSubscription = null;
    if (_stopStartedAt != null) {
      _stoppedDuration += DateTime.now().difference(_stopStartedAt!);
      _stopStartedAt = null;
    }
    final endTime = DateTime.now();
    final totalDuration = endTime.difference(_startTime!);
    final movingSeconds = (totalDuration - _stoppedDuration).inSeconds;
    final averageSpeed = movingSeconds > 0
        ? _distanceMeters / movingSeconds
        : 0.0;
    final first = _routePoints.first;
    final last = _routePoints.last;
    final ride = TrackedRide(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      rideName: _rideName,
      startTime: _startTime!,
      endTime: endTime,
      startLatitude: first.latitude,
      startLongitude: first.longitude,
      endLatitude: last.latitude,
      endLongitude: last.longitude,
      totalDistanceMeters: _distanceMeters,
      maximumSpeedMetersPerSecond: _maximumSpeed,
      averageSpeedMetersPerSecond: averageSpeed,
      totalDuration: totalDuration,
      stoppedDuration: _stoppedDuration,
      stopCount: _stopCount,
      points: List.unmodifiable(_routePoints),
    );
    await _storage.saveRide(ride);
    _completedRides.insert(0, ride);
    _isTracking = false;
    _startTime = null;
    _activeRideId = null;
    clearRideDestination();
    _rideName = null;
    _selectedRide = ride;
    notifyListeners();
    return ride;
  }

  void selectRide(TrackedRide? ride) {
    _selectedRide = ride;
    if (ride != null && !_isTracking) {
      _currentPosition = Position(
        longitude: ride.endLongitude,
        latitude: ride.endLatitude,
        timestamp: ride.endTime,
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
    notifyListeners();
  }

  List<RidePoint> get visiblePoints => _isTracking
      ? routePoints
      : (_selectedRide?.points ?? const <RidePoint>[]);

  void _initCompass() {
    _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        _compassHeading = event.heading!;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    _durationTimer?.cancel();
    _destinationReachedController.close();
    super.dispose();
  }
}

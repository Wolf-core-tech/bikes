import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/tracked_ride.dart';
import '../providers/ride_provider.dart';
import '../providers/ride_tracking_provider.dart';
import '../services/cached_tile_provider.dart';
import '../services/map_service.dart';
import '../services/ride_report_service.dart';
import '../theme/app_theme.dart';

class MapTabScreen extends StatefulWidget {
  final VoidCallback? onRideEnded;
  const MapTabScreen({super.key, this.onRideEnded});

  @override
  State<MapTabScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<MapTabScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final RideReportService _reportService = RideReportService();
  double _zoom = 17.0;
  bool _autoStartRequested = false;
  bool _followMode = true; // Google Maps camera-follow mode

  // For planned route display
  List<LatLng> _plannedRoute = [];
  LatLng? _routeDestination;
  String? _destinationLabel;
  bool _isFetchingRoute = false;

  // For smooth arrow animation
  late AnimationController _headingAnimController;
  late Animation<double> _headingAnim;
  double _previousHeading = 0.0;

  // Tile caching
  CachedTileProvider? _tileProvider;

  @override
  void initState() {
    super.initState();
    _headingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _headingAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _headingAnimController, curve: Curves.easeOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RideTrackingProvider>().loadCurrentLocation();
      }
    });
    // Initialize disk tile cache
    CachedTileProvider.create().then((provider) {
      if (mounted) setState(() => _tileProvider = provider);
    });
  }

  @override
  void dispose() {
    _headingAnimController.dispose();
    super.dispose();
  }

  void _animateHeading(double newHeading) {
    double delta = newHeading - _previousHeading;
    // Shortest rotation path
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    final targetRad = (_previousHeading + delta) * math.pi / 180.0;
    _headingAnim = Tween<double>(
      begin: _previousHeading * math.pi / 180.0,
      end: targetRad,
    ).animate(
      CurvedAnimation(parent: _headingAnimController, curve: Curves.easeOut),
    );
    _headingAnimController.forward(from: 0);
    _previousHeading = _previousHeading + delta;
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<RideTrackingProvider>();
    final setup = context.watch<RideSetup>();

    // Animate heading whenever it changes
    _animateHeading(tracking.compassHeading);

    final visiblePoints = tracking.visiblePoints;
    final current =
        tracking.currentLatLng ??
        (visiblePoints.isNotEmpty
            ? LatLng(visiblePoints.last.latitude, visiblePoints.last.longitude)
            : const LatLng(20, 0));

    final drivenRoute = visiblePoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Auto-start logic
    if (setup.isComplete &&
        !tracking.isTracking &&
        tracking.selectedRide == null &&
        !_autoStartRequested) {
      _autoStartRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<RideTrackingProvider>().startRide();
      });
    } else if (!setup.isComplete) {
      _autoStartRequested = false;
    }

    // Google Maps-style: follow location and map rotation while tracking
    if (tracking.isTracking && tracking.currentLatLng != null && _followMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Rotate map so heading is always "up"
        _mapController.moveAndRotate(
          tracking.currentLatLng!,
          _zoom,
          -tracking.compassHeading,
        );
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      body: Stack(
        children: [
          // ── MAP ──────────────────────────────────────────────────
          ColorFiltered(
            colorFilter: isDark
                ? const ColorFilter.matrix([
                    -0.7, 0, 0, 0, 255,
                    0, -0.7, 0, 0, 255,
                    0, 0, -0.7, 0, 255,
                    0, 0, 0, 1, 0,
                  ])
                : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: current,
                initialZoom: _zoom,
                interactionOptions: InteractionOptions(
                  flags: _followMode && tracking.isTracking
                      ? InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom
                      : InteractiveFlag.all,
                ),
                onPositionChanged: (pos, hasGesture) {
                  _zoom = pos.zoom;
                  // If user manually drags, turn off follow mode
                  if (hasGesture && tracking.isTracking) {
                    setState(() => _followMode = false);
                  }
                },
              ),
              children: [
                // ── Tile layer with disk caching (loads like Google Maps) ──
                TileLayer(
                  // OpenStreetMap (free + open-source) served via fast CDN
                  // Tiles are cached to disk — loads instantly after first visit
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.bikers',
                  tileProvider: _tileProvider ?? NetworkTileProvider(),
                  retinaMode: MediaQuery.of(context).devicePixelRatio > 1,
                  maxZoom: 19,
                  maxNativeZoom: 19,
                  // Pre-load 5 tiles around viewport for smooth panning
                  keepBuffer: 5,
                  // Pan buffer = load tiles slightly outside screen
                  panBuffer: 2,
                  tileDisplay: const TileDisplay.fadeIn(
                    duration: Duration(milliseconds: 100),
                  ),
                ),
                // OSM attribution (required by license)
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
                      onTap: () {},
                    ),
                  ],
                ),

                // Planned route line (blue) — shown before/during ride if destination set
                if (_plannedRoute.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _plannedRoute,
                        color: Colors.blue.withValues(alpha: 0.7),
                        strokeWidth: 6,
                      ),
                    ],
                  ),

                // Driven/actual route line (orange)
                if (drivenRoute.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: drivenRoute,
                        color: AppColors.orange,
                        strokeWidth: 5,
                      ),
                    ],
                  ),

                MarkerLayer(
                  markers: [
                    // ── WHILE TRACKING ──────────────────────────────
                    // Green START pin (only if we've moved from start)
                    if (tracking.isTracking &&
                        drivenRoute.length > 2)
                      _buildMarker(
                        drivenRoute.first,
                        Colors.green,
                        Icons.trip_origin,
                        size: 36,
                      ),

                    // ── AFTER RIDE (viewing history) ─────────────────
                    if (!tracking.isTracking && drivenRoute.isNotEmpty)
                      _buildMarker(
                        drivenRoute.first,
                        Colors.green,
                        Icons.trip_origin,
                        size: 36,
                      ),
                    if (!tracking.isTracking && drivenRoute.length > 1)
                      _buildMarker(
                        drivenRoute.last,
                        AppColors.danger,
                        Icons.flag,
                        size: 36,
                      ),

                    // ── DESTINATION pin (planned route) ───────────────
                    // Only ONE pin at the exact geocoded destination
                    if (_routeDestination != null)
                      _buildMarker(
                        _routeDestination!,
                        const Color(0xFF1565C0),   // deep blue
                        Icons.location_pin,
                        size: 44,
                        label: _destinationLabel,
                      ),

                    // ── CURRENT POSITION arrow (single, animated) ─────
                    if (tracking.currentLatLng != null)
                      _buildNavArrow(tracking.currentLatLng!),
                  ],
                ),

              ],
            ),
          ),

          // ── TOP BAR ──────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.themedSurface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.directions_bike, color: AppColors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tracking.isTracking
                            ? (_destinationLabel != null
                                ? 'Riding to: $_destinationLabel'
                                : 'Free Ride in Progress')
                            : (tracking.selectedRide == null
                                ? 'Ready to Ride'
                                : 'Ride Report'),
                        style: TextStyle(
                          color: AppColors.themedText,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Error message inline
                    if (tracking.errorMessage != null)
                      Icon(Icons.warning_amber, color: AppColors.danger, size: 20),
                  ],
                ),
              ),
            ),
          ),

          // ── RIGHT SIDE BUTTONS ────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 290,
            child: Column(
              children: [
                _mapBtn(
                  icon: Icons.add,
                  onTap: () {
                    setState(() => _zoom = (_zoom + 1).clamp(3.0, 20.0));
                    _mapController.move(current, _zoom);
                  },
                ),
                const SizedBox(height: 8),
                _mapBtn(
                  icon: Icons.remove,
                  onTap: () {
                    setState(() => _zoom = (_zoom - 1).clamp(3.0, 20.0));
                    _mapController.move(current, _zoom);
                  },
                ),
                const SizedBox(height: 8),
                // My Location / Re-centre button
                _mapBtn(
                  icon: _followMode && tracking.isTracking
                      ? Icons.navigation
                      : Icons.my_location,
                  color: (_followMode && tracking.isTracking)
                      ? AppColors.orange
                      : null,
                  onTap: () {
                    if (tracking.currentLatLng != null) {
                      setState(() {
                        _zoom = 17.0;
                        _followMode = true;
                      });
                      _mapController.moveAndRotate(
                        tracking.currentLatLng!,
                        _zoom,
                        -tracking.compassHeading,
                      );
                    }
                  },
                ),
                if (tracking.isTracking && _plannedRoute.isEmpty) ...[
                  const SizedBox(height: 8),
                  // North up toggle
                  _mapBtn(
                    icon: Icons.explore,
                    onTap: () {
                      _mapController.rotate(0);
                    },
                    tooltip: 'Reset to North Up',
                  ),
                ],
              ],
            ),
          ),

          // ── BOTTOM PANEL ─────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MetricsPanel(tracking: tracking),
                _RideActions(
                  tracking: tracking,
                  setup: setup,
                  reportService: _reportService,
                  onRideEnded: widget.onRideEnded,
                  onStartWithRoute: _handleStartWithRoute,
                  onFreeRide: _handleFreeRide,
                ),
                _HistorySection(tracking: tracking),
              ],
            ),
          ),

          // Route fetching banner
          if (_isFetchingRoute)
            Positioned(
              left: 12,
              right: 12,
              top: 100,
              child: Material(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text('Calculating road route...',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          // Error banner
          if (tracking.errorMessage != null)
            Positioned(
              left: 12,
              right: 12,
              top: 100,
              child: Material(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    tracking.errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Animated navigation arrow marker ─────────────────────────────
  Marker _buildNavArrow(LatLng point) {
    return Marker(
      point: point,
      width: 56,
      height: 56,
      child: AnimatedBuilder(
        animation: _headingAnim,
        builder: (context, _) => Transform.rotate(
          angle: _headingAnim.value,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  // ── Generic map marker ────────────────────────────────────────────
  Marker _buildMarker(LatLng point, Color color, IconData icon,
      {double size = 40, String? label}) {
    return Marker(
      point: point,
      width: size + (label != null ? 20 : 0),
      height: size + (label != null ? 20 : 0),
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ],
      ),
    );
  }

  Widget _mapBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    String? tooltip,
  }) {
    return Material(
      color: AppColors.themedSurface,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: color ?? AppColors.themedText, size: 22),
          ),
        ),
      ),
    );
  }

  // Called when user picks a destination — starts ride immediately, fetches route in background
  Future<void> _handleStartWithRoute(
      LatLng destination, String destLabel) async {
    final tracking = context.read<RideTrackingProvider>();
    final currentLoc = tracking.currentLatLng;
    if (currentLoc == null) return;

    setState(() {
      _routeDestination = destination;
      _destinationLabel = destLabel;
      _plannedRoute = [];
      _followMode = true;
      _isFetchingRoute = true;
    });

    // Start GPS tracking immediately — don't wait for route
    final started = await tracking.startRide();
    if (!started && mounted && tracking.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tracking.errorMessage!)));
    }

    // Fetch route in background concurrently
    final mapSvc = MapService();
    final route = await mapSvc.getRoute(currentLoc, destination);
    if (mounted) {
      setState(() {
        _isFetchingRoute = false;
        _plannedRoute = route.isNotEmpty ? route : [currentLoc, destination];
      });
      // Zoom map to show the full route
      _fitRouteBounds(currentLoc, destination);
    }
  }

  void _fitRouteBounds(LatLng start, LatLng end) {
    final minLat = start.latitude < end.latitude ? start.latitude : end.latitude;
    final maxLat = start.latitude > end.latitude ? start.latitude : end.latitude;
    final minLon = start.longitude < end.longitude ? start.longitude : end.longitude;
    final maxLon = start.longitude > end.longitude ? start.longitude : end.longitude;
    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);

    // Estimate zoom: larger distance → smaller zoom
    final latDiff = (maxLat - minLat).abs();
    final lonDiff = (maxLon - minLon).abs();
    final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

    double zoom;
    if (maxDiff < 0.01) {
      zoom = 15;
    } else if (maxDiff < 0.05) {
      zoom = 13;
    } else if (maxDiff < 0.1) {
      zoom = 12;
    } else if (maxDiff < 0.5) {
      zoom = 10;
    } else if (maxDiff < 1.0) {
      zoom = 9;
    } else if (maxDiff < 3.0) {
      zoom = 8;
    } else {
      zoom = 7;
    }

    setState(() {
      _zoom = zoom;
      _followMode = false; // don't auto-follow so user can see full route
    });
    _mapController.move(center, zoom);
  }

  // Called for free ride
  Future<void> _handleFreeRide() async {
    final tracking = context.read<RideTrackingProvider>();
    setState(() {
      _plannedRoute = [];
      _routeDestination = null;
      _destinationLabel = null;
      _followMode = true;
    });
    final started = await tracking.startRide();
    if (!started && mounted && tracking.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tracking.errorMessage!)));
    }
  }
}

// ── Metrics Panel ────────────────────────────────────────────────────
class _MetricsPanel extends StatelessWidget {
  final RideTrackingProvider tracking;
  const _MetricsPanel({required this.tracking});

  String _fmt(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) return '${p(d.inHours)}:${p(d.inMinutes % 60)}:${p(d.inSeconds % 60)}';
    return '${p(d.inMinutes % 60)}:${p(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final dur = tracking.isTracking
        ? tracking.rideDuration
        : (tracking.selectedRide?.totalDuration ?? Duration.zero);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.themedSurface,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Metric(label: 'Distance', value: '${tracking.distanceKm.toStringAsFixed(2)} km'),
            _divider(),
            _Metric(label: 'Time', value: _fmt(dur)),
            _divider(),
            _Metric(label: 'Speed', value: '${tracking.currentSpeedKmh.toStringAsFixed(1)} km/h'),
            _divider(),
            _Metric(label: 'Max', value: '${tracking.maximumSpeedKmh.toStringAsFixed(1)} km/h'),
            _divider(),
            _Metric(label: 'Stops', value: '${tracking.stopCount}'),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        height: 32,
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: AppColors.themedGrey.withValues(alpha: 0.3),
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: TextStyle(color: AppColors.themedGrey, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: AppColors.themedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      );
}

// ── Ride Actions ─────────────────────────────────────────────────────
class _RideActions extends StatelessWidget {
  final RideTrackingProvider tracking;
  final RideSetup setup;
  final RideReportService reportService;
  final VoidCallback? onRideEnded;
  final Future<void> Function(LatLng dest, String label) onStartWithRoute;
  final Future<void> Function() onFreeRide;

  const _RideActions({
    required this.tracking,
    required this.setup,
    required this.reportService,
    required this.onStartWithRoute,
    required this.onFreeRide,
    this.onRideEnded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(tracking.isTracking ? Icons.stop : Icons.play_arrow),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    tracking.isTracking ? AppColors.danger : AppColors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () =>
                  tracking.isTracking ? _stop(context) : _showStartDialog(context),
              label: Text(tracking.isTracking ? 'STOP RIDE' : 'START RIDE',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          if (!tracking.isTracking && tracking.selectedRide != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => reportService.printReport(tracking.selectedRide!),
                label: const Text('Generate PDF Report'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showStartDialog(BuildContext context) async {
    final tracking = context.read<RideTrackingProvider>();
    final currentLoc = tracking.currentLatLng;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StartRideSheet(
        currentLocation: currentLoc,
        onStartWithRoute: (dest, label) {
          Navigator.pop(ctx);
          onStartWithRoute(dest, label);
        },
        onFreeRide: () {
          Navigator.pop(ctx);
          onFreeRide();
        },
      ),
    );
  }

  Future<void> _stop(BuildContext context) async {
    final ride = await tracking.stopRide();
    if (ride == null || !context.mounted) return;
    setup.endRide();
    onRideEnded?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride saved! PDF report is ready.')),
    );
  }
}

// ── Start Ride Bottom Sheet ───────────────────────────────────────────
class _StartRideSheet extends StatefulWidget {
  final LatLng? currentLocation;
  final void Function(LatLng dest, String label) onStartWithRoute;
  final VoidCallback onFreeRide;

  const _StartRideSheet({
    required this.currentLocation,
    required this.onStartWithRoute,
    required this.onFreeRide,
  });

  @override
  State<_StartRideSheet> createState() => _StartRideSheetState();
}

class _StartRideSheetState extends State<_StartRideSheet> {
  final _toController = TextEditingController();
  bool _useCurrentAsFrom = true;
  bool _isSearching = false;
  String? _error;

  final MapService _mapService = MapService();

  @override
  void dispose() {
    _toController.dispose();
    super.dispose();
  }

  Future<void> _startWithRoute() async {
    final toText = _toController.text.trim();
    if (toText.isEmpty) {
      setState(() => _error = 'Please enter a destination');
      return;
    }
    if (widget.currentLocation == null) {
      setState(() => _error = 'Current location not available');
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    final dest = await _mapService.geocodeLocation(toText);
    if (!mounted) return;

    if (dest == null) {
      setState(() {
        _isSearching = false;
        _error = 'Could not find "$toText". Try a more specific location.';
      });
      return;
    }

    setState(() => _isSearching = false);
    widget.onStartWithRoute(dest, toText);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.themedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 20),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.themedGrey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.directions_bike, color: AppColors.orange, size: 28),
              const SizedBox(width: 10),
              Text(
                'Start a Ride',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.themedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // FROM field
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.themedBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.trip_origin, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: _useCurrentAsFrom
                      ? Row(
                          children: [
                            Text(
                              'Current Location',
                              style: TextStyle(
                                  color: AppColors.themedText,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('GPS',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10)),
                            ),
                          ],
                        )
                      : Text('Your location',
                          style: TextStyle(color: AppColors.themedGrey)),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _useCurrentAsFrom = !_useCurrentAsFrom),
                  child: Icon(
                    _useCurrentAsFrom
                        ? Icons.my_location
                        : Icons.location_on_outlined,
                    color: AppColors.orange,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Column(
              children: List.generate(
                  3,
                  (_) => Container(
                        width: 2,
                        height: 6,
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        color: AppColors.themedGrey.withValues(alpha: 0.4),
                      )),
            ),
          ),
          const SizedBox(height: 4),

          // TO field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.themedBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_pin, color: Colors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _toController,
                    decoration: InputDecoration(
                      hintText: 'Search destination...',
                      hintStyle: TextStyle(color: AppColors.themedGrey),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: TextStyle(color: AppColors.themedText),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _startWithRoute(),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                if (_toController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _toController.clear();
                      setState(() => _error = null);
                    },
                    child: Icon(Icons.clear,
                        color: AppColors.themedGrey, size: 18),
                  ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Start with Route button
          ElevatedButton.icon(
            icon: _isSearching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.map_outlined),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSearching ? null : _startWithRoute,
            label: Text(
              _isSearching ? 'Finding Route...' : 'START WITH NAVIGATION',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 10),

          // Free Ride button
          OutlinedButton.icon(
            icon: const Icon(Icons.directions_bike_outlined),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.orange,
              side: BorderSide(color: AppColors.orange),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: widget.onFreeRide,
            label: const Text(
              'FREE RIDE (No Destination)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── History Section ──────────────────────────────────────────────────
class _HistorySection extends StatelessWidget {
  final RideTrackingProvider tracking;
  const _HistorySection({required this.tracking});

  @override
  Widget build(BuildContext context) {
    if (tracking.completedRides.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 110,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        scrollDirection: Axis.horizontal,
        itemCount: tracking.completedRides.length,
        itemBuilder: (ctx, i) {
          final ride = tracking.completedRides[i];
          return _HistoryCard(
            ride: ride,
            onTap: () => tracking.selectRide(ride),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final TrackedRide ride;
  final VoidCallback onTap;
  const _HistoryCard({required this.ride, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        child: Card(
          color: AppColors.themedCard,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ride.startTime.day}/${ride.startTime.month}/${ride.startTime.year}',
                    style: TextStyle(
                        color: AppColors.themedText,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ride.distanceKm.toStringAsFixed(1)} km  |  ${ride.averageSpeedKmh.toStringAsFixed(1)} km/h avg',
                    style:
                        TextStyle(color: AppColors.themedGrey, fontSize: 12),
                  ),
                  Text(
                    '${ride.totalDuration.inMinutes} min  |  ${ride.maximumSpeedKmh.toStringAsFixed(1)} km/h max',
                    style:
                        TextStyle(color: AppColors.themedGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

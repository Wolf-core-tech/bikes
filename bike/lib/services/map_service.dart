import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapService {
  static const _timeout = Duration(seconds: 15);

  // ── Geocode: text → LatLng ────────────────────────────────────────
  Future<LatLng?> geocodeLocation(String query) async {
    if (query.trim().isEmpty) return null;
    try {
      // Try with India bias first (most users are in India)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query.trim())}'
        '&format=json&limit=1&addressdetails=0'
        '&countrycodes=in',          // prioritise India
      );
      final res = await http
          .get(url, headers: {
            'User-Agent': 'BikeSquadApp/1.0',
            'Accept-Language': 'en',
          })
          .timeout(_timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List<dynamic>;
        if (data.isNotEmpty) {
          return LatLng(
            double.parse(data[0]['lat'] as String),
            double.parse(data[0]['lon'] as String),
          );
        }
      }

      // Fallback: worldwide search
      final url2 = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query.trim())}'
        '&format=json&limit=1',
      );
      final res2 = await http
          .get(url2, headers: {'User-Agent': 'BikeSquadApp/1.0'})
          .timeout(_timeout);

      if (res2.statusCode == 200) {
        final data2 = json.decode(res2.body) as List<dynamic>;
        if (data2.isNotEmpty) {
          return LatLng(
            double.parse(data2[0]['lat'] as String),
            double.parse(data2[0]['lon'] as String),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Routing: LatLng → LatLng, real road route ─────────────────────
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    // Try servers in order: 1 → 2 → 3 → straight-line
    final servers = [
      // Official OSRM demo (HTTPS)
      'https://router.project-osrm.org/route/v1/driving'
          '/${start.longitude},${start.latitude}'
          ';${end.longitude},${end.latitude}'
          '?geometries=geojson&overview=full&generate_hints=false',
      // OpenStreetMap DE routing (alternate, often fast in Asia)
      'https://routing.openstreetmap.de/routed-car/route/v1/driving'
          '/${start.longitude},${start.latitude}'
          ';${end.longitude},${end.latitude}'
          '?geometries=geojson&overview=full&generate_hints=false',
    ];

    for (final urlStr in servers) {
      final result = await _tryFetch(urlStr);
      if (result.isNotEmpty) return result;
    }

    // Last resort: straight-line with 30 interpolated midpoints
    return _straightLine(start, end, steps: 30);
  }

  Future<List<LatLng>> _tryFetch(String urlStr) async {
    try {
      final res = await http
          .get(
            Uri.parse(urlStr),
            headers: {'User-Agent': 'BikeSquadApp/1.0'},
          )
          .timeout(_timeout);

      if (res.statusCode != 200) return [];

      final body = json.decode(res.body) as Map<String, dynamic>;
      if ((body['code'] as String?) != 'Ok') return [];

      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return [];

      final coords =
          routes[0]['geometry']['coordinates'] as List<dynamic>;
      if (coords.isEmpty) return [];

      return coords
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<LatLng> _straightLine(LatLng start, LatLng end, {int steps = 30}) {
    return List.generate(steps + 1, (i) {
      final t = i / steps;
      return LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t,
      );
    });
  }
}

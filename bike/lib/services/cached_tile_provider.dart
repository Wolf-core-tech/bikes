import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// A flutter_map TileProvider that:
/// 1. Serves tiles from disk cache (instant, like Google Maps)
/// 2. Downloads & caches tiles on first load
/// 3. Falls back gracefully on network failure
class CachedTileProvider extends TileProvider {
  CachedTileProvider._();

  static CachedTileProvider? _instance;
  static String _cacheDir = '';
  static final http.Client _client = http.Client();

  static Future<CachedTileProvider> create() async {
    if (_instance != null) return _instance!;
    final dir = await getTemporaryDirectory();
    _cacheDir = '${dir.path}/osm_tile_cache';
    await Directory(_cacheDir).create(recursive: true);
    _instance = CachedTileProvider._();
    return _instance!;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CachedTileImage(
      url: getTileUrl(coordinates, options),
      cacheDir: _cacheDir,
      client: _client,
    );
  }
}

@immutable
class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  final String url;
  final String cacheDir;
  final http.Client client;

  const _CachedTileImage({
    required this.url,
    required this.cacheDir,
    required this.client,
  });

  String get _filename {
    // Use the last part of the URL as a safe filename
    final sanitized = url
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final key =
        sanitized.length > 180 ? sanitized.substring(sanitized.length - 180) : sanitized;
    return '$key.png';
  }

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration config) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      _CachedTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    Uint8List? bytes;

    // ── 1. Try disk cache first (instant) ──────────────────────
    try {
      final file = File('$cacheDir/$_filename');
      if (await file.exists()) {
        bytes = await file.readAsBytes();
      }
    } catch (_) {}

    // ── 2. Download from network ────────────────────────────────
    if (bytes == null) {
      try {
        final response = await client
            .get(
              Uri.parse(url),
              headers: {
                'User-Agent': 'BikeSquadApp/1.0 (contact@bikesquad.app)',
              },
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          bytes = response.bodyBytes;
          // Save to disk cache in background (don't block rendering)
          _saveToCache(bytes);
        }
      } catch (_) {}
    }

    // ── 3. Fallback: transparent tile ──────────────────────────
    if (bytes == null || bytes.isEmpty) {
      bytes = _transparentPng();
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  void _saveToCache(Uint8List bytes) {
    // Fire & forget — write to disk without blocking
    Future.microtask(() async {
      try {
        await File('$cacheDir/$_filename').writeAsBytes(bytes);
      } catch (_) {}
    });
  }

  // 1×1 transparent PNG fallback
  Uint8List _transparentPng() => Uint8List.fromList([
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
        0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222,
        0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 15, 0, 0, 1, 1,
        0, 5, 24, 213, 78, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 82, 130,
      ]);

  @override
  bool operator ==(Object other) =>
      other is _CachedTileImage && url == other.url;

  @override
  int get hashCode => url.hashCode;
}

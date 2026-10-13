import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import './sentinel_map_renderer.dart';

// ── Mapbox access token (injected at build time) ──────────────────────────────
const String _kMapboxToken = String.fromEnvironment(
  'MAPBOX_ACCESS_TOKEN',
  defaultValue: '',
);
const String _kMapboxStyle = 'mapbox://styles/mapbox/standard';

/// Creates a MapboxMapRenderer (native) or delegates to web on web platform.
/// This function is the conditional-import target for non-web.
SentinelMapRenderer createRenderer({
  Key? key,
  required double initialLng,
  required double initialLat,
  double initialZoom = 18.0,
  double initialPitch = 50.0,
  double initialBearing = 0.0,
  required OnMapReadyCallback onMapReady,
  required OnCameraChangedCallback onCameraChanged,
  required OnMapScrollCallback onMapScroll,
}) {
  return _MapboxMapRendererWidget(
    key: key,
    initialLng: initialLng,
    initialLat: initialLat,
    initialZoom: initialZoom,
    initialPitch: initialPitch,
    initialBearing: initialBearing,
    onMapReady: onMapReady,
    onCameraChanged: onCameraChanged,
    onMapScroll: onMapScroll,
  );
}

class _MapboxMapRendererWidget extends SentinelMapRenderer {
  const _MapboxMapRendererWidget({
    super.key,
    required super.initialLng,
    required super.initialLat,
    super.initialZoom,
    super.initialPitch,
    super.initialBearing,
    required super.onMapReady,
    required super.onCameraChanged,
    required super.onMapScroll,
  });

  @override
  SentinelMapRendererState<_MapboxMapRendererWidget> createState() =>
      MapboxMapRendererState();
}

/// Public state class so it can be accessed via GlobalKey.
class MapboxMapRendererState
    extends SentinelMapRendererState<_MapboxMapRendererWidget> {
  MapboxMap? _mapboxMap;

  double _zoom = 18.0;
  double _pitch = 50.0;
  double _bearing = 0.0;

  @override
  double get currentZoom => _zoom;
  @override
  double get currentPitch => _pitch;
  @override
  double get currentBearing => _bearing;

  @override
  void initState() {
    super.initState();
    _zoom = widget.initialZoom;
    _pitch = widget.initialPitch;
    _bearing = widget.initialBearing;

    if (_kMapboxToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_kMapboxToken);
    }
  }

  @override
  Future<void> flyTo({
    required double lng,
    required double lat,
    required double zoom,
    required double pitch,
    required double bearing,
    int durationMs = 800,
  }) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
        pitch: pitch,
        bearing: bearing,
      ),
      MapAnimationOptions(duration: durationMs, startDelay: 0),
    );
  }

  @override
  Future<void> fitBounds({
    required List<(double lat, double lng)> coordinates,
    double maxZoom = 15.0,
    double pitch = 15.0,
    double bearing = 0.0,
  }) async {
    if (_mapboxMap == null || coordinates.isEmpty) return;

    if (coordinates.length == 1) {
      await flyTo(
        lng: coordinates.first.$2,
        lat: coordinates.first.$1,
        zoom: maxZoom,
        pitch: pitch,
        bearing: bearing,
      );
      return;
    }

    double minLat = coordinates.first.$1;
    double maxLat = coordinates.first.$1;
    double minLng = coordinates.first.$2;
    double maxLng = coordinates.first.$2;

    for (final c in coordinates) {
      if (c.$1 < minLat) minLat = c.$1;
      if (c.$1 > maxLat) maxLat = c.$1;
      if (c.$2 < minLng) minLng = c.$2;
      if (c.$2 > maxLng) maxLng = c.$2;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final maxDiff = math.max(maxLat - minLat, maxLng - minLng);
    double zoom = maxZoom;
    if (maxDiff < 0.005) {
      zoom = 15.0;
    } else if (maxDiff < 0.02) {
      zoom = 13.5;
    } else if (maxDiff < 0.1) {
      zoom = 12.0;
    } else if (maxDiff < 0.5) {
      zoom = 10.0;
    } else {
      zoom = 8.0;
    }

    await flyTo(
      lng: centerLng,
      lat: centerLat,
      zoom: zoom,
      pitch: pitch,
      bearing: bearing,
      durationMs: 1200,
    );
  }

  @override
  Future<Offset?> coordinateToScreen(double lat, double lng) async {
    if (_mapboxMap == null) return null;
    try {
      final sc = await _mapboxMap!.pixelForCoordinate(
        Point(coordinates: Position(lng, lat)),
      );
      return Offset(sc.x, sc.y);
    } catch (_) {
      return null;
    }
  }

  void _onMapCreated(MapboxMap controller) {
    _mapboxMap = controller;
    widget.onMapReady(controller);
  }

  void _onStyleLoaded(StyleLoadedEventData _) {}

  void _onCameraChanged(CameraChangedEventData data) {
    final s = data.cameraState;
    if (mounted) {
      setState(() {
        _zoom = s.zoom;
        _pitch = s.pitch;
        _bearing = s.bearing;
      });
      widget.onCameraChanged(zoom: s.zoom, pitch: s.pitch, bearing: s.bearing);
    }
  }

  void _onMapScroll(MapContentGestureContext _) {
    widget.onMapScroll();
  }

  @override
  Widget build(BuildContext context) {
    if (_kMapboxToken.isEmpty) {
      return _buildTokenPlaceholder();
    }

    return MapWidget(
      key: const ValueKey('sentinel_mapbox'),
      styleUri: _kMapboxStyle,
      viewport: CameraViewportState(
        center: Point(
          coordinates: Position(widget.initialLng, widget.initialLat),
        ),
        zoom: widget.initialZoom,
        pitch: widget.initialPitch,
        bearing: widget.initialBearing,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
      onCameraChangeListener: _onCameraChanged,
      onScrollListener: _onMapScroll,
    );
  }

  Widget _buildTokenPlaceholder() {
    return Container(
      color: const Color(0xFF1A2332),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_rounded,
                size: 64,
                color: Colors.teal.withAlpha(180),
              ),
              const SizedBox(height: 16),
              const Text(
                'Configura tu MAPBOX_ACCESS_TOKEN\npara activar el mapa Sentinel.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Añade tu token en env.json:\n"MAPBOX_ACCESS_TOKEN": "pk.eyJ1..."',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

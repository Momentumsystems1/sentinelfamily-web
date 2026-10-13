import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import './sentinel_map_renderer.dart';

/// Creates a WebMapRenderer — used on web/Rocket preview.
/// This is the conditional-import target for dart.library.html.
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
  return _WebMapRendererWidget(
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

class _WebMapRendererWidget extends SentinelMapRenderer {
  const _WebMapRendererWidget({
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
  SentinelMapRendererState<_WebMapRendererWidget> createState() =>
      WebMapRendererState();
}

/// Public state so it can be accessed via GlobalKey.
class WebMapRendererState
    extends SentinelMapRendererState<_WebMapRendererWidget> {
  late final MapController _mapController;

  double _zoom = 18.0;
  final double _pitch = 0.0; // flutter_map is 2D — pitch always 0
  double _bearing = 0.0;

  // Track map render box for coordinate conversion
  final GlobalKey _mapKey = GlobalKey();

  @override
  double get currentZoom => _zoom;
  @override
  double get currentPitch => _pitch;
  @override
  double get currentBearing => _bearing;

  @override
  void initState() {
    super.initState();
    _zoom = widget.initialZoom.clamp(1.0, 20.0);
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
    if (!mounted) return;
    _mapController.move(LatLng(lat, lng), zoom.clamp(1.0, 20.0));
    if (mounted) {
      setState(() {
        _zoom = zoom.clamp(1.0, 20.0);
        _bearing = bearing;
      });
      widget.onCameraChanged(zoom: _zoom, pitch: 0.0, bearing: bearing);
    }
  }

  @override
  Future<void> fitBounds({
    required List<(double lat, double lng)> coordinates,
    double maxZoom = 15.0,
    double pitch = 15.0,
    double bearing = 0.0,
  }) async {
    if (coordinates.isEmpty || !mounted) return;

    if (coordinates.length == 1) {
      await flyTo(
        lng: coordinates.first.$2,
        lat: coordinates.first.$1,
        zoom: maxZoom,
        pitch: 0,
        bearing: 0,
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

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  @override
  Future<Offset?> coordinateToScreen(double lat, double lng) async {
    if (!mounted) return null;
    try {
      final point = _mapController.camera.latLngToScreenOffset(LatLng(lat, lng));
      return Offset(point.dx, point.dy);
    } catch (_) {
      return null;
    }
  }

  void _onMapEvent(MapEvent event) {
    if (!mounted) return;
    if (event is MapEventMove || event is MapEventRotate) {
      final cam = _mapController.camera;
      setState(() {
        _zoom = cam.zoom;
        _bearing = cam.rotation;
      });
      widget.onCameraChanged(zoom: cam.zoom, pitch: 0.0, bearing: cam.rotation);
    }
    if (event is MapEventScrollWheelZoom ||
        event is MapEventFlingAnimation ||
        event is MapEventDoubleTapZoom) {
      widget.onMapScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      key: _mapKey,
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(widget.initialLat, widget.initialLng),
        initialZoom: _zoom,
        minZoom: 3.0,
        maxZoom: 20.0,
        onMapEvent: _onMapEvent,
        onMapReady: () {
          // Signal map ready — pass the controller as the generic controller
          widget.onMapReady(_mapController);
        },
        onPositionChanged: (pos, _) {
          if (!mounted) return;
          final newZoom = pos.zoom ?? _zoom;
          if ((newZoom - _zoom).abs() > 0.01) {
            setState(() => _zoom = newZoom);
            widget.onCameraChanged(
              zoom: newZoom,
              pitch: 0.0,
              bearing: _bearing,
            );
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.sentinel.app',
          maxZoom: 20,
        ),
      ],
    );
  }
}
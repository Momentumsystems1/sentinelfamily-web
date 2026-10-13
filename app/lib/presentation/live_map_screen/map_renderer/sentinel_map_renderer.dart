import 'package:flutter/material.dart';

// Conditional import: on web (dart.library.html) → web_map_renderer.dart
//                     on native (dart.library.io) → mapbox_map_renderer.dart
import 'web_map_renderer.dart';  // BUILD FIN DE SEMANA: renderizador OSM también en Android (Mapbox requiere token secreto)

/// Callback types shared by all renderers.
typedef OnMapReadyCallback = void Function(dynamic mapController);
typedef OnCameraChangedCallback =
    void Function({
      required double zoom,
      required double pitch,
      required double bearing,
    });
typedef OnMapScrollCallback = void Function();

/// ═══════════════════════════════════════════════════════════════════════════
/// SentinelMapRenderer — abstract contract for all map backends.
///
/// Architecture:
///   SentinelMapRenderer
///   ├─ Android/iOS → MapboxMapRenderer  (mapbox_map_renderer.dart)
///   └─ Web/Rocket Preview → WebMapRenderer (web_map_renderer.dart)
///
/// Shared logic that lives OUTSIDE the renderer:
///   - GPS / displayPosition
///   - active group
///   - PersonMapData
///   - PersonDetailSheet
///   - member locations
///   - Supabase
///
/// The renderer is ONLY responsible for:
///   - Displaying the map tiles / 3D environment
///   - Providing camera control (flyTo, fitBounds)
///   - Reporting camera state changes
///   - Providing screen-coordinate conversion for overlay positioning
/// ═══════════════════════════════════════════════════════════════════════════
abstract class SentinelMapRenderer extends StatefulWidget {
  /// Initial camera center (longitude, latitude).
  final double initialLng;
  final double initialLat;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;

  /// Called once when the map is ready to accept camera commands.
  final OnMapReadyCallback onMapReady;

  /// Called on every camera change (pan, zoom, rotate, tilt).
  final OnCameraChangedCallback onCameraChanged;

  /// Called when the user manually scrolls/pans the map.
  final OnMapScrollCallback onMapScroll;

  const SentinelMapRenderer({
    super.key,
    required this.initialLng,
    required this.initialLat,
    this.initialZoom = 18.0,
    this.initialPitch = 50.0,
    this.initialBearing = 0.0,
    required this.onMapReady,
    required this.onCameraChanged,
    required this.onMapScroll,
  });

  /// Platform-aware factory.
  ///
  /// On Android/iOS: returns MapboxMapRenderer (3D, pitch, heading).
  /// On Web/Rocket Preview: returns WebMapRenderer (flutter_map + OSM, 2D).
  ///
  /// The conditional import at the top of this file routes `createRenderer`
  /// to the correct implementation automatically.
  factory SentinelMapRenderer.forPlatform({
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
    return createRenderer(
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
}

/// State interface that all renderer states must implement.
/// Accessed via GlobalKey<SentinelMapRendererState>.
abstract class SentinelMapRendererState<T extends SentinelMapRenderer>
    extends State<T> {
  /// Fly camera to a coordinate with animation.
  Future<void> flyTo({
    required double lng,
    required double lat,
    required double zoom,
    required double pitch,
    required double bearing,
    int durationMs = 800,
  });

  /// Fit camera to show all given coordinates.
  Future<void> fitBounds({
    required List<(double lat, double lng)> coordinates,
    double maxZoom = 15.0,
    double pitch = 15.0,
    double bearing = 0.0,
  });

  /// Convert a geographic coordinate to screen pixel offset.
  /// Returns null if the coordinate is off-screen or map not ready.
  Future<Offset?> coordinateToScreen(double lat, double lng);

  /// Current camera zoom level.
  double get currentZoom;

  /// Current camera pitch.
  double get currentPitch;

  /// Current camera bearing.
  double get currentBearing;
}

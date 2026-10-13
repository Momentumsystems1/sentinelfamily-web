import '../traffic_incident_provider.dart';

/// Mapbox Traffic incident provider.
///
/// STATUS: STUB — API not yet implemented.
/// Returns empty list until Mapbox Traffic Events API is integrated.
///
/// Mapbox Traffic Events API:
///   GET https://events.mapbox.com/traffic/v1/incidents
///   Requires: MAPBOX_ACCESS_TOKEN (already configured in env.json)
///
/// When implemented, this provider will:
///   1. Call Mapbox Traffic Events API with bounding box
///   2. Parse GeoJSON FeatureCollection response
///   3. Map Mapbox congestion/incident types to [TrafficSeverity] / [TrafficIncidentType]
///   4. Return normalized [TrafficIncident] list prefixed with "mapbox:"
///
/// Note: Mapbox also provides a visual traffic layer via the Standard style.
/// This provider is for the normalized incident data model only.
class MapboxTrafficProvider implements TrafficIncidentProvider {
  /// Mapbox access token — injected at build time.
  static const String _token = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  const MapboxTrafficProvider();

  @override
  String get providerName => 'Mapbox Traffic';

  @override
  String get providerId => 'mapbox';

  @override
  bool get isEnabled => _token.isNotEmpty;

  @override
  Future<List<TrafficIncident>> getIncidents(TrafficBounds bounds) async {
    // NOT IMPLEMENTED — returns empty list.
    // Do not add fake incidents.
    return const [];
  }

  @override
  void dispose() {}
}

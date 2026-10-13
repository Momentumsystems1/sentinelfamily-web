/// ═══════════════════════════════════════════════════════════════════════════
/// TrafficIncident — normalized model consumed by the map renderer.
///
/// All traffic providers (Azure, DGT, SCT, Mapbox) must convert their
/// provider-specific data into this model before passing it to the map.
/// The map renderer never depends on provider-specific types.
/// ═══════════════════════════════════════════════════════════════════════════
library;

/// Severity levels normalized across all providers.
enum TrafficSeverity { unknown, low, moderate, high, critical }

/// Incident type normalized across all providers.
enum TrafficIncidentType {
  unknown,
  accident,
  congestion,
  roadwork,
  closure,
  hazard,
  weather,
  other,
}

/// Normalized traffic incident model.
///
/// Fields are nullable when the source provider does not supply them.
/// Never fabricate values — leave null if unavailable.
class TrafficIncident {
  /// Unique identifier (provider-prefixed, e.g. "azure:12345").
  final String id;

  /// Source provider identifier (e.g. "azure", "dgt", "sct", "mapbox").
  final String source;

  /// Normalized incident type.
  final TrafficIncidentType type;

  /// Normalized severity.
  final TrafficSeverity severity;

  /// Short human-readable title.
  final String title;

  /// Optional longer description.
  final String? description;

  /// Geographic position — latitude.
  final double lat;

  /// Geographic position — longitude.
  final double lng;

  /// When the incident started (UTC). Null if unknown.
  final DateTime? startTime;

  /// When the incident is expected to end (UTC). Null if unknown or ongoing.
  final DateTime? endTime;

  /// Road name or identifier. Null if unknown.
  final String? road;

  /// Direction of travel affected. Null if unknown.
  final String? direction;

  const TrafficIncident({
    required this.id,
    required this.source,
    required this.type,
    required this.severity,
    required this.title,
    this.description,
    required this.lat,
    required this.lng,
    this.startTime,
    this.endTime,
    this.road,
    this.direction,
  });

  @override
  String toString() =>
      'TrafficIncident(id: $id, source: $source, type: $type, '
      'severity: $severity, title: $title, lat: $lat, lng: $lng)';
}

/// Bounding box for incident queries.
class TrafficBounds {
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  const TrafficBounds({
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
  });

  @override
  String toString() => 'TrafficBounds([$minLat,$minLng] → [$maxLat,$maxLng])';
}

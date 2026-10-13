import './traffic_incident.dart';

export 'traffic_incident.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TrafficIncidentProvider — abstract contract for all traffic data sources.
///
/// Sentinel supports multiple simultaneous traffic sources:
///   - Mapbox Traffic (visual layer + incidents)
///   - Azure Maps Traffic
///   - DGT DATEX II (Spain)
///   - SCT DATEX II (Mexico)
///
/// Each provider implements this interface and converts its native data
/// format into the normalized [TrafficIncident] model.
///
/// The map renderer consumes [TrafficIncident] only — never provider types.
/// This allows combining multiple providers without changing map UI.
/// ═══════════════════════════════════════════════════════════════════════════
abstract class TrafficIncidentProvider {
  /// Human-readable provider name (e.g. "Azure Maps Traffic").
  String get providerName;

  /// Short identifier (e.g. "azure", "dgt", "sct", "mapbox").
  String get providerId;

  /// Whether this provider is currently enabled and configured.
  bool get isEnabled;

  /// Fetch incidents within the given [bounds].
  ///
  /// Returns an empty list (never throws) if the provider is unavailable,
  /// not configured, or returns no data for the area.
  ///
  /// Implementations must:
  ///   - Normalize all fields to [TrafficIncident]
  ///   - Prefix [TrafficIncident.id] with [providerId] + ":"
  ///   - Never return fake/mock incidents
  ///   - Return [] if API is not yet implemented
  Future<List<TrafficIncident>> getIncidents(TrafficBounds bounds);

  /// Optional: dispose resources (HTTP clients, streams, etc.).
  void dispose() {}
}

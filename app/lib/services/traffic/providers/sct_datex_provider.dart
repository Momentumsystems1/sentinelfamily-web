import '../traffic_incident_provider.dart';

/// SCT (Secretaría de Comunicaciones y Transportes, Mexico) DATEX II provider.
///
/// STATUS: STUB — API not yet implemented.
/// Returns empty list until SCT DATEX II feed is integrated.
///
/// When implemented, this provider will:
///   1. Fetch SCT DATEX II feed
///   2. Parse SituationRecord elements
///   3. Filter by bounding box
///   4. Map SCT severity/type to [TrafficSeverity] / [TrafficIncidentType]
///   5. Return normalized [TrafficIncident] list prefixed with "sct:"
class SctDatexProvider implements TrafficIncidentProvider {
  const SctDatexProvider();

  @override
  String get providerName => 'SCT DATEX II';

  @override
  String get providerId => 'sct';

  @override
  bool get isEnabled => true; // Public feed — no key required

  @override
  Future<List<TrafficIncident>> getIncidents(TrafficBounds bounds) async {
    // NOT IMPLEMENTED — returns empty list.
    // Do not add fake incidents.
    return const [];
  }

  @override
  void dispose() {}
}

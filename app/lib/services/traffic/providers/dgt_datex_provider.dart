import '../traffic_incident_provider.dart';

/// DGT (Dirección General de Tráfico, Spain) DATEX II incident provider.
///
/// STATUS: STUB — API not yet implemented.
/// Returns empty list until DGT DATEX II feed is integrated.
///
/// DGT DATEX II endpoint (public):
///   https://infocar.dgt.es/datex2/
///   No authentication required for public feeds.
///
/// When implemented, this provider will:
///   1. Fetch DGT DATEX II XML/JSON feed
///   2. Parse SituationRecord elements
///   3. Filter by bounding box
///   4. Map DGT severity/type to [TrafficSeverity] / [TrafficIncidentType]
///   5. Return normalized [TrafficIncident] list prefixed with "dgt:"
class DgtDatexProvider implements TrafficIncidentProvider {
  const DgtDatexProvider();

  @override
  String get providerName => 'DGT DATEX II';

  @override
  String get providerId => 'dgt';

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

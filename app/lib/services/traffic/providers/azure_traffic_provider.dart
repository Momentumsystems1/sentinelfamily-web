import '../traffic_incident_provider.dart';

/// Azure Maps Traffic incident provider.
///
/// STATUS: STUB — API not yet implemented.
/// Returns empty list until Azure Maps credentials are configured
/// and the REST API integration is built.
///
/// Azure Maps Traffic API:
///   GET https://atlas.microsoft.com/traffic/incident/tile/json
///   Requires: subscription-key (Azure Maps account)
///
/// When implemented, this provider will:
///   1. Call Azure Maps Traffic Incidents API with bounding box
///   2. Parse the JSON response
///   3. Map Azure severity/type enums to [TrafficSeverity] / [TrafficIncidentType]
///   4. Return normalized [TrafficIncident] list prefixed with "azure:"
class AzureTrafficProvider implements TrafficIncidentProvider {
  /// Azure Maps subscription key.
  /// Set via String.fromEnvironment('AZURE_MAPS_KEY') when implemented.
  final String? subscriptionKey;

  const AzureTrafficProvider({this.subscriptionKey});

  @override
  String get providerName => 'Azure Maps Traffic';

  @override
  String get providerId => 'azure';

  @override
  bool get isEnabled => subscriptionKey != null && subscriptionKey!.isNotEmpty;

  @override
  Future<List<TrafficIncident>> getIncidents(TrafficBounds bounds) async {
    // NOT IMPLEMENTED — returns empty list.
    // Do not add fake incidents.
    return const [];
  }

  @override
  void dispose() {}
}

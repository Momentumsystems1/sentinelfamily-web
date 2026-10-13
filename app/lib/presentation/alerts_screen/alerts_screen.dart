import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import './widgets/alert_card_widget.dart';
import './widgets/alert_summary_bar_widget.dart';
import './widgets/alerts_chart_widget.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'all';
  List<Map<String, dynamic>> _alertMaps = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _alertChannel;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  @override
  void dispose() {
    _alertChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rawAlerts = await SupabaseService.instance.getMyAlerts();
      if (mounted) {
        setState(() {
          _alertMaps = rawAlerts.map(_mapAlert).toList();
          _isLoading = false;
        });
        _subscribeToAlerts();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar alertas';
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToAlerts() {
    _alertChannel?.unsubscribe();
    _alertChannel = SupabaseService.instance.subscribeToAlerts([], (payload) {
      if (mounted) _loadAlerts();
    });
  }

  Map<String, dynamic> _mapAlert(Map<String, dynamic> raw) {
    final profile = raw['profiles'] as Map<String, dynamic>?;
    final kind = raw['kind'] as String? ?? 'incident';
    final status = raw['status'] as String? ?? 'open';
    final createdAt = raw['created_at'] as String?;

    String formattedTime = '';
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        formattedTime = DateFormat('dd/MM/yyyy · HH:mm').format(dt);
      } catch (_) {}
    }

    String alertType;
    String alertTitle;
    switch (kind) {
      case 'emergency':
        alertType = 'emergency';
        alertTitle = 'SOS activado';
        break;
      case 'ok_check':
        alertType = 'checkin';
        alertTitle = '¿Todo bien?';
        break;
      default:
        alertType = 'incident';
        alertTitle = 'Incidencia';
    }

    String alertStatus;
    switch (status) {
      case 'resolved':
        alertStatus = 'resolved';
        break;
      case 'escalated':
      case 'emergency':
        alertStatus = 'active';
        break;
      case 'private_warning':
        alertStatus = 'acknowledged';
        break;
      default:
        alertStatus = 'active';
    }

    return {
      'id': raw['id']?.toString() ?? '',
      'type': alertType,
      'title': alertTitle,
      'memberName': profile?['display_name'] as String? ?? 'Usuario',
      'memberImageUrl': null,
      'memberSemanticLabel': 'Member profile photo',
      'location': raw['lat'] != null
          ? 'Lat: ${(raw['lat'] as double).toStringAsFixed(4)}'
          : 'Ubicación desconocida',
      'timestamp': formattedTime,
      'status': alertStatus,
      'description': _buildDescription(kind, status),
      'rawId': raw['id'],
    };
  }

  String _buildDescription(String kind, String status) {
    switch (kind) {
      case 'emergency':
        return 'Botón SOS activado manualmente. Ubicación exacta compartida con el grupo.';
      case 'ok_check':
        return 'Check-in automático activado.';
      default:
        return 'Incidencia detectada. Estado: $status.';
    }
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_filter == 'all') return _alertMaps;
    return _alertMaps.where((a) => a['type'] == _filter).toList();
  }

  int _countByType(String type) =>
      _alertMaps.where((a) => a['type'] == type).length;

  int _countActive() => _alertMaps.where((a) => a['status'] == 'active').length;

  Future<void> _acknowledge(String alertId, dynamic rawId) async {
    setState(() {
      final idx = _alertMaps.indexWhere((a) => a['id'] == alertId);
      if (idx != -1) _alertMaps[idx]['status'] = 'acknowledged';
    });
    if (rawId != null) {
      await SupabaseService.instance.updateAlertStatus(
        alertId: rawId as int,
        status: 'private_warning',
      );
    }
  }

  Future<void> _escalate(String alertId, dynamic rawId) async {
    setState(() {
      final idx = _alertMaps.indexWhere((a) => a['id'] == alertId);
      if (idx != -1) _alertMaps[idx]['status'] = 'active';
    });
    if (rawId != null) {
      await SupabaseService.instance.updateAlertStatus(
        alertId: rawId as int,
        status: 'escalated',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: AppTheme.primaryContainer,
        title: Text(
          'Alertas',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          if (_countActive() > 0)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.sosContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_countActive()} activa${_countActive() > 1 ? 's' : ''}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.sos,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppTheme.primary,
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadAlerts,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  AlertSummaryBarWidget(
                    emergencyCount: _countByType('emergency'),
                    incidentCount: _countByType('incident'),
                    checkinCount: _countByType('checkin'),
                    activeCount: _countActive(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('all', 'Todas'),
                          const SizedBox(width: 8),
                          _filterChip('emergency', 'Emergencias'),
                          const SizedBox(width: 8),
                          _filterChip('incident', 'Incidencias'),
                          const SizedBox(width: 8),
                          _filterChip('checkin', 'Check-ins'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _filteredAlerts.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.notifications_off_outlined,
                            title: 'Sin alertas',
                            description:
                                'Cuando ocurra algo, las alertas aparecerán aquí con toda la información.',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAlerts,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: _filteredAlerts.length + 1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                if (i == _filteredAlerts.length) {
                                  return const AlertsChartWidget();
                                }
                                final alert = _filteredAlerts[i];
                                return AlertCardWidget(
                                  alert: alert,
                                  onAcknowledge: () => _acknowledge(
                                    alert['id'] as String,
                                    alert['rawId'],
                                  ),
                                  onEscalate: () => _escalate(
                                    alert['id'] as String,
                                    alert['rawId'],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(51),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

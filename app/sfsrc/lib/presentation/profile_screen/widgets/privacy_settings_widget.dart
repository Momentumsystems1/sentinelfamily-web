import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class PrivacySettingsWidget extends StatelessWidget {
  final bool locationExact;
  final bool locationBackground;
  final bool batteryStatus;
  final bool routeHistory;
  final bool checkinNotifications;
  final Function(String, bool) onChanged;

  const PrivacySettingsWidget({
    required this.locationExact,
    required this.locationBackground,
    required this.batteryStatus,
    required this.routeHistory,
    required this.checkinNotifications,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.privacy_tip_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('Privacidad activa', style: theme.textTheme.titleSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.successContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Visible ahora',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Controla qué compartes con tu grupo en este momento.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _privacyToggle(
            theme,
            key: 'locationExact',
            icon: Icons.gps_fixed_rounded,
            label: 'Ubicación exacta',
            sublabel: 'GPS preciso',
            value: locationExact,
          ),
          _privacyToggle(
            theme,
            key: 'locationBackground',
            icon: Icons.location_on_outlined,
            label: 'Ubicación en segundo plano',
            sublabel: 'Cuando la app está cerrada',
            value: locationBackground,
          ),
          _privacyToggle(
            theme,
            key: 'batteryStatus',
            icon: Icons.battery_4_bar_rounded,
            label: 'Estado de batería',
            sublabel: 'Visible para tu grupo',
            value: batteryStatus,
          ),
          _privacyToggle(
            theme,
            key: 'routeHistory',
            icon: Icons.route_rounded,
            label: 'Historial de rutas',
            sublabel: 'Últimas 24h guardadas',
            value: routeHistory,
          ),
          _privacyToggle(
            theme,
            key: 'checkinNotifications',
            icon: Icons.notifications_active_rounded,
            label: 'Avisos de llegada',
            sublabel: 'Notificar al llegar a destinos',
            value: checkinNotifications,
          ),
        ],
      ),
    );
  }

  Widget _privacyToggle(
    ThemeData theme, {
    required String key,
    required IconData icon,
    required String label,
    required String sublabel,
    required bool value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? AppTheme.primaryContainer
                  : AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: value ? AppTheme.primary : AppTheme.statusGhost,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  sublabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) => onChanged(key, v),
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class AlertSummaryBarWidget extends StatelessWidget {
  final int emergencyCount;
  final int incidentCount;
  final int checkinCount;
  final int activeCount;

  const AlertSummaryBarWidget({
    required this.emergencyCount,
    required this.incidentCount,
    required this.checkinCount,
    required this.activeCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          _statCell(
            context,
            emergencyCount.toString(),
            'Emergencias',
            AppTheme.sos,
          ),
          _divider(),
          _statCell(
            context,
            incidentCount.toString(),
            'Incidencias',
            AppTheme.warning,
          ),
          _divider(),
          _statCell(
            context,
            checkinCount.toString(),
            'Check-ins',
            AppTheme.success,
          ),
          _divider(),
          _statCell(context, activeCount.toString(), 'Activas', AppTheme.error),
        ],
      ),
    );
  }

  Widget _statCell(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class MemberDetailSheetWidget extends StatelessWidget {
  final Map<String, dynamic> member;

  const MemberDetailSheetWidget({required this.member, super.key});

  String _formatLastSeen(String? updatedAt) {
    if (updatedAt == null) return 'Desconocido';
    try {
      final dt = DateTime.parse(updatedAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds}s';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
      return 'Hace ${diff.inDays}d';
    } catch (_) {
      return 'Desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final battery = member['battery'] as int?; // null = unknown
    final lastSeen = member['lastSeen'] as String?;
    final speed = member['speed'] as int?; // null = unknown

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.35,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(
                        member['color'] as int? ?? AppTheme.primary.value,
                      ),
                      border: Border.all(
                        color: AppTheme.primaryContainer,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        ((member['name'] as String?) ?? 'U').isNotEmpty
                            ? ((member['name'] as String?) ?? 'U')[0]
                                  .toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (member['name'] as String?) ?? 'Usuario',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ubicación en tiempo real',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _infoCard(theme, [
                _InfoRow(
                  Icons.access_time_rounded,
                  'Última actualización',
                  _formatLastSeen(lastSeen),
                ),
                if (speed != null)
                  _InfoRow(Icons.speed_rounded, 'Velocidad', '$speed km/h'),
                _InfoRow(
                  Icons.battery_4_bar_rounded,
                  'Batería',
                  battery != null ? '$battery%' : 'No disponible',
                ),
              ]),
              const SizedBox(height: 12),
              _sharingCard(theme),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _infoCard(ThemeData theme, List<_InfoRow> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: rows.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(r.icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 10),
                Text(
                  r.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  r.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sharingCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.success.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withAlpha(51)),
      ),
      child: Row(
        children: [
          Icon(Icons.gps_fixed_rounded, color: AppTheme.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Compartiendo ubicación exacta',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  _InfoRow(this.icon, this.label, this.value);
}

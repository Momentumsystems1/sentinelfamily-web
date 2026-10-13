import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class GroupCardWidget extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onTap;

  /// Null means the current user does not have permission to invite.
  final VoidCallback? onInvite;

  const GroupCardWidget({
    required this.group,
    required this.onTap,
    required this.onInvite,
    super.key,
  });

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':
        return AppTheme.primary;
      case 'admin':
        return AppTheme.secondary;
      case 'guest':
        return AppTheme.warning;
      default:
        return AppTheme.statusGhost;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Propietario';
      case 'admin':
        return 'Admin';
      case 'guest':
        return 'Invitado';
      default:
        return 'Miembro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // All optional fields — safe null access, never crash
    final hasAlert = (group['hasActiveAlert'] as bool?) ?? false;
    final myRole = (group['myRole'] as String?) ?? 'member';
    final members = (group['members'] as List?) ?? [];
    final activeCount = (group['activeCount'] as int?) ?? 0;
    final memberCount = (group['memberCount'] as int?) ?? 0;
    final description = group['description'] as String?;
    final lastActivity = group['lastActivity'] as String?;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: AppTheme.primaryContainer.withAlpha(77),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasAlert
                ? AppTheme.sos.withAlpha(77)
                : theme.colorScheme.outlineVariant,
            width: hasAlert ? 1.5 : 1,
          ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (group['name'] as String?) ?? 'Grupo',
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasAlert) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.sosContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.warning_rounded,
                                    size: 10,
                                    color: AppTheme.sos,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Alerta',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.sos,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                // Overlapping member avatars (avatar_color based)
                if (members.isNotEmpty)
                  SizedBox(
                    width: (members.length.clamp(0, 4) * 22 + 8).toDouble(),
                    height: 32,
                    child: Stack(
                      children: List.generate(members.length.clamp(0, 4), (i) {
                        final member = members[i] as Map?;
                        final profile = member?['profiles'] as Map?;
                        final colorHex =
                            profile?['avatar_color'] as String? ?? '#06AED5';
                        Color avatarColor;
                        try {
                          final h = colorHex.replaceAll('#', '');
                          avatarColor = Color(int.parse('FF$h', radix: 16));
                        } catch (_) {
                          avatarColor = AppTheme.primary;
                        }
                        final initial =
                            ((profile?['display_name'] as String?) ?? 'U')
                                .isNotEmpty
                            ? ((profile?['display_name'] as String?) ?? 'U')[0]
                                  .toUpperCase()
                            : 'U';
                        return Positioned(
                          left: i * 22.0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: avatarColor,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  '$activeCount/$memberCount miembros',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: activeCount > 0
                        ? AppTheme.success
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _roleColor(myRole).withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _roleLabel(myRole),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _roleColor(myRole),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (lastActivity != null) ...[
                  Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    lastActivity,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                if (onInvite != null)
                  OutlinedButton.icon(
                    onPressed: onInvite,
                    icon: const Icon(Icons.person_add_outlined, size: 14),
                    label: const Text('Invitar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(color: AppTheme.primary.withAlpha(128)),
                      foregroundColor: AppTheme.primary,
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

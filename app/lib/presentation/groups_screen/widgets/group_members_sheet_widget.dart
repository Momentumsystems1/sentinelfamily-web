import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';

class GroupMembersSheetWidget extends StatelessWidget {
  final Map<String, dynamic> group;

  const GroupMembersSheetWidget({required this.group, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = group['members'] as List;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group['name'] as String,
                            style: theme.textTheme.headlineSmall,
                          ),
                          Text(
                            '${group['memberCount']} miembros · ${group['activeCount']} activos',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Gestionar',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final m = members[i] as Map;
                    final status = m['status'] as String;
                    final role = m['role'] as String;

                    BadgeStatus badgeStatus;
                    switch (status) {
                      case 'online':
                        badgeStatus = BadgeStatus.online;
                        break;
                      case 'ghost':
                        badgeStatus = BadgeStatus.ghost;
                        break;
                      default:
                        badgeStatus = BadgeStatus.offline;
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: CustomImageWidget(
                                    imageUrl: m['imageUrl'] as String,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    semanticLabel: m['semanticLabel'] as String,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: StatusBadgeWidget(
                                  status: badgeStatus,
                                  compact: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['name'] as String,
                                  style: theme.textTheme.titleSmall,
                                ),
                                Row(
                                  children: [
                                    _roleChip(role),
                                    if (m.containsKey('guestExpiresAt')) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        'Caduca: ${m['guestExpiresAt']}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          color: AppTheme.warning,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                            onPressed: () {},
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roleChip(String role) {
    Color c;
    String label;
    switch (role) {
      case 'owner':
        c = AppTheme.primary;
        label = 'Propietario';
        break;
      case 'admin':
        c = AppTheme.secondary;
        label = 'Admin';
        break;
      case 'guest':
        c = AppTheme.warning;
        label = 'Invitado';
        break;
      default:
        c = AppTheme.statusGhost;
        label = 'Miembro';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withAlpha(26),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}

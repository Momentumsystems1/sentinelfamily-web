import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

/// Member avatar strip — quick selector for group members.
/// Tapping a member centers their PersonMapObject and opens PersonDetailSheet.
class MemberAvatarStripWidget extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final Function(String) onMemberTapped;

  const MemberAvatarStripWidget({
    required this.members,
    required this.onMemberTapped,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(242),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final m = members[i];
          final name = m['name'] as String? ?? 'U';
          final avatarUrl = m['avatarUrl'] as String?;
          final colorVal = m['color'] as int?;
          final avatarColor = colorVal != null
              ? Color(colorVal)
              : AppTheme.primary;
          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

          return GestureDetector(
            onTap: () => onMemberTapped(m['id'] as String),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarColor,
                    border: Border.all(color: AppTheme.statusOnline, width: 2),
                  ),
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 40,
                  child: Text(
                    name.split(' ').first,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

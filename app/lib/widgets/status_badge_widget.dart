import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum BadgeStatus { online, ghost, offline, warning, emergency, info, success }

class StatusBadgeWidget extends StatelessWidget {
  final BadgeStatus status;
  final String? label;
  final bool compact;

  const StatusBadgeWidget({
    required this.status,
    this.label,
    this.compact = false,
    super.key,
  });

  Color _bgColor() {
    switch (status) {
      case BadgeStatus.online:
        return AppTheme.successContainer;
      case BadgeStatus.ghost:
        return const Color(0xFFEEEEEE);
      case BadgeStatus.offline:
        return const Color(0xFFF5F5F5);
      case BadgeStatus.warning:
        return AppTheme.warningContainer;
      case BadgeStatus.emergency:
        return AppTheme.sosContainer;
      case BadgeStatus.info:
        return const Color(0xFFE3F2FD);
      case BadgeStatus.success:
        return AppTheme.successContainer;
    }
  }

  Color _textColor() {
    switch (status) {
      case BadgeStatus.online:
        return AppTheme.success;
      case BadgeStatus.ghost:
        return AppTheme.statusGhost;
      case BadgeStatus.offline:
        return AppTheme.statusOffline;
      case BadgeStatus.warning:
        return AppTheme.warning;
      case BadgeStatus.emergency:
        return AppTheme.sos;
      case BadgeStatus.info:
        return const Color(0xFF1565C0);
      case BadgeStatus.success:
        return AppTheme.success;
    }
  }

  String _defaultLabel() {
    switch (status) {
      case BadgeStatus.online:
        return 'En línea';
      case BadgeStatus.ghost:
        return 'Fantasma';
      case BadgeStatus.offline:
        return 'Sin conexión';
      case BadgeStatus.warning:
        return 'Aviso';
      case BadgeStatus.emergency:
        return 'Emergencia';
      case BadgeStatus.info:
        return 'Info';
      case BadgeStatus.success:
        return 'OK';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _textColor(),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label ?? _defaultLabel(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _textColor(),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

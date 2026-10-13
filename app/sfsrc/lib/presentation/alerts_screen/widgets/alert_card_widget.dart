import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';

class AlertCardWidget extends StatefulWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onAcknowledge;
  final VoidCallback onEscalate;

  const AlertCardWidget({
    required this.alert,
    required this.onAcknowledge,
    required this.onEscalate,
    super.key,
  });

  @override
  State<AlertCardWidget> createState() => _AlertCardWidgetState();
}

class _AlertCardWidgetState extends State<AlertCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    if (widget.alert['status'] == 'active' &&
        widget.alert['type'] == 'emergency') {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color _borderColor() {
    final type = widget.alert['type'] as String;
    final status = widget.alert['status'] as String;
    if (status == 'resolved') return const Color(0xFFEEEEEE);
    switch (type) {
      case 'emergency':
        return AppTheme.sos;
      case 'incident':
        return AppTheme.warning;
      default:
        return AppTheme.success;
    }
  }

  Color _bgColor() {
    final type = widget.alert['type'] as String;
    final status = widget.alert['status'] as String;
    if (status == 'resolved') return Colors.white;
    switch (type) {
      case 'emergency':
        return AppTheme.sosContainer.withAlpha(51);
      case 'incident':
        return AppTheme.warningContainer.withAlpha(51);
      default:
        return AppTheme.successContainer.withAlpha(51);
    }
  }

  IconData _typeIcon() {
    switch (widget.alert['type'] as String) {
      case 'emergency':
        return Icons.sos_rounded;
      case 'incident':
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  Color _iconColor() {
    switch (widget.alert['type'] as String) {
      case 'emergency':
        return AppTheme.sos;
      case 'incident':
        return AppTheme.warning;
      default:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = widget.alert['status'] == 'active';
    final isResolved = widget.alert['status'] == 'resolved';

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: isActive && widget.alert['type'] == 'emergency'
            ? _pulse.value
            : 1.0,
        child: child,
      ),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _bgColor(),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _borderColor(),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _borderColor().withAlpha(38),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _iconColor().withAlpha(31),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_typeIcon(), color: _iconColor(), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.alert['title'] as String,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: isResolved
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        Text(
                          widget.alert['memberName'] as String,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statusBadge(theme),
                      const SizedBox(height: 4),
                      Text(
                        widget.alert['timestamp'] as String,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ClipOval(
                    child: CustomImageWidget(
                      imageUrl: widget.alert['memberImageUrl'] as String,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      semanticLabel:
                          widget.alert['memberSemanticLabel'] as String,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      widget.alert['location'] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(153),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.alert['description'] as String,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              if (!isResolved) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.alert['status'] != 'acknowledged')
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onAcknowledge,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(
                              color: _iconColor().withAlpha(102),
                            ),
                            foregroundColor: _iconColor(),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Reconocer'),
                        ),
                      ),
                    if (widget.alert['status'] != 'acknowledged')
                      const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: widget.alert['type'] == 'emergency'
                            ? widget.onEscalate
                            : widget.onAcknowledge,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: _iconColor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(
                          widget.alert['type'] == 'emergency'
                              ? 'Escalar'
                              : 'Resolver',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(ThemeData theme) {
    final status = widget.alert['status'] as String;
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = _iconColor().withAlpha(38);
        textColor = _iconColor();
        label = 'Activa';
        break;
      case 'acknowledged':
        bgColor = AppTheme.warningContainer;
        textColor = AppTheme.warning;
        label = 'Reconocida';
        break;
      default:
        bgColor = AppTheme.successContainer;
        textColor = AppTheme.success;
        label = 'Resuelta';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class GhostModeChipWidget extends StatefulWidget {
  final bool isActive;
  final int? minutesRemaining;
  final VoidCallback onToggle;

  const GhostModeChipWidget({
    required this.isActive,
    required this.minutesRemaining,
    required this.onToggle,
    super.key,
  });

  @override
  State<GhostModeChipWidget> createState() => _GhostModeChipWidgetState();
}

class _GhostModeChipWidgetState extends State<GhostModeChipWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    if (widget.isActive) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(GhostModeChipWidget old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isActive) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _pulse.value : 1.0,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.black.withAlpha(204)
                : Colors.white.withAlpha(242),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(31),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isActive
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 16,
                color: widget.isActive ? Colors.white : AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.isActive
                    ? 'Fantasma${widget.minutesRemaining != null ? ' · ${widget.minutesRemaining}min' : ''}'
                    : 'Visible',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isActive ? Colors.white : AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

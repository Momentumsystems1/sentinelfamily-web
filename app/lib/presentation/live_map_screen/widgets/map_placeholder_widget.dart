import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../core/app_export.dart';

class MapPlaceholderWidget extends StatelessWidget {
  const MapPlaceholderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // TODO: Replace with flutter_map + OpenStreetMap tiles for production
    // Service not configured — showing map placeholder per UX mandate
    return Container(
      width: size.width,
      height: size.height,
      color: const Color(0xFFE8F0EE),
      child: Stack(
        children: [
          // Grid lines simulating map tiles
          CustomPaint(size: size, painter: _MapGridPainter()),
          // Street lines
          CustomPaint(size: size, painter: _StreetPainter()),
          // Map not configured notice
          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Mapa: servicio no configurado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Member pins on the placeholder map
          ..._buildMemberPins(size),
        ],
      ),
    );
  }

  List<Widget> _buildMemberPins(Size size) {
    final positions = [
      Offset(size.width * 0.45, size.height * 0.40),
      Offset(size.width * 0.62, size.height * 0.52),
      Offset(size.width * 0.30, size.height * 0.55),
      Offset(size.width * 0.70, size.height * 0.35),
    ];
    final colors = [
      AppTheme.primary,
      const Color(0xFF1565C0),
      const Color(0xFF7B1FA2),
      AppTheme.statusGhost,
    ];
    return List.generate(positions.length, (i) {
      return Positioned(
        left: positions[i].dx - 18,
        top: positions[i].dy - 36,
        child: _MapPin(color: colors[i]),
      );
    });
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  const _MapPin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(102),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _PinTailPainter(color: color),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCD9D6).withAlpha(128)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => false;
}

class _StreetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final streetPaint = Paint()
      ..color = Colors.white.withAlpha(230)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = Colors.white.withAlpha(179)
      ..strokeWidth = 3;

    // Main streets
    canvas.drawLine(
      Offset(0, size.height * 0.45),
      Offset(size.width, size.height * 0.45),
      streetPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.55, 0),
      Offset(size.width * 0.55, size.height),
      streetPaint,
    );
    // Minor streets
    canvas.drawLine(
      Offset(0, size.height * 0.25),
      Offset(size.width, size.height * 0.25),
      minorPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.65),
      Offset(size.width, size.height * 0.65),
      minorPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.30, 0),
      Offset(size.width * 0.30, size.height),
      minorPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, 0),
      Offset(size.width * 0.75, size.height),
      minorPaint,
    );
  }

  @override
  bool shouldRepaint(_StreetPainter old) => false;
}

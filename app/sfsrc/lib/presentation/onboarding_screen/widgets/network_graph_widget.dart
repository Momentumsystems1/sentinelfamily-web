import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class NetworkGraphWidget extends StatefulWidget {
  const NetworkGraphWidget({super.key});

  @override
  State<NetworkGraphWidget> createState() => _NetworkGraphWidgetState();
}

class _NetworkGraphWidgetState extends State<NetworkGraphWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnim;
  late Animation<double> _scaleAnim;

  final List<Map<String, dynamic>> _members = [
    {
      'imageUrl':
          'https://img.rocket.new/generatedImages/rocket_gen_img_11b96b2f1-1763294850372.png',
      'semanticLabel': 'Woman with dark hair smiling, profile photo',
      'angle': 0.0,
    },
    {
      'imageUrl':
          'https://images.unsplash.com/photo-1570030633716-ca5fd78a2ea4',
      'semanticLabel': 'Young man with beard, casual portrait',
      'angle': math.pi / 3,
    },
    {
      'imageUrl':
          'https://images.pixabay.com/photo/2017/08/01/08/29/woman-2563491_960_720.jpg?w=80',
      'semanticLabel': 'Older woman with glasses, warm smile',
      'angle': 2 * math.pi / 3,
    },
    {
      'imageUrl': 'https://images.unsplash.com/photo-1547736771-439298e93228',
      'semanticLabel': 'Young man with short hair, outdoor setting',
      'angle': math.pi,
    },
    {
      'imageUrl':
          'https://images.pexels.com/photos/774909/pexels-photo-774909.jpeg?w=80',
      'semanticLabel': 'Teenage girl with ponytail, natural light',
      'angle': 4 * math.pi / 3,
    },
    {
      'imageUrl':
          'https://images.pixabay.com/photo/2016/11/21/12/42/beard-1845166_960_720.jpg?w=80',
      'semanticLabel': 'Middle-aged man with beard, professional',
      'angle': 5 * math.pi / 3,
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _rotateAnim = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_controller);
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.1, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer arc
                CustomPaint(
                  size: const Size(260, 260),
                  painter: _ArcPainter(color: AppTheme.primaryContainer),
                ),
                // Inner arc
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _ArcPainter(color: AppTheme.secondaryContainer),
                ),
                // Center logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(77),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                // Member avatars on orbit
                ..._members.map((m) {
                  final angle = m['angle'] as double;
                  final radius = 120.0;
                  final x = radius * math.cos(angle + _rotateAnim.value * 0.05);
                  final y = radius * math.sin(angle + _rotateAnim.value * 0.05);
                  return Positioned(
                    left: 140 + x - 22,
                    top: 140 + y - 22,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(26),
                            blurRadius: 8,
                          ),
                        ],
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
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -math.pi * 0.7,
      math.pi * 1.4,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

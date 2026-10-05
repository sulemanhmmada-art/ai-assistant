import 'package:flutter/material.dart';
import 'dart:math' as math;

enum OrbState { idle, thinking, speaking }

class AiOrbWidget extends StatefulWidget {
  final OrbState state;
  final double size;

  const AiOrbWidget({
    super.key,
    this.state = OrbState.idle,
    this.size = 140.0,
  });

  @override
  State<AiOrbWidget> createState() => _AiOrbWidgetState();
}

class _AiOrbWidgetState extends State<AiOrbWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double speedMultiplier = 1.0;
    if (widget.state == OrbState.thinking) speedMultiplier = 2.5;
    if (widget.state == OrbState.speaking) speedMultiplier = 1.8;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = (_controller.value * speedMultiplier) % 1.0;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _OrbPainter(
              progress: progress,
              state: widget.state,
            ),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double progress;
  final OrbState state;

  _OrbPainter({required this.progress, required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;

    // الطبقة الأولى: الهالة الخارجية المضيئة
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF10A37F).withOpacity(0.6),
          const Color(0xFF764BA2).withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.2, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(center, radius * (1.1 + math.sin(progress * 2 * math.pi) * 0.08), glowPaint);

    // الطبقة الثانية: نواة الكرة المتوهجة
    final coreGradient = SweepGradient(
      transform: GradientRotation(progress * 2 * math.pi),
      colors: const [
        Color(0xFF764BA2),
        Color(0xFF10A37F),
        Color(0xFF00D2FF),
        Color(0xFF764BA2),
      ],
    );

    final corePaint = Paint()
      ..shader = coreGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, corePaint);

    // الطبقة الثالثة: حلقات الطاقة الداخلية
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final ringRadius = radius * (0.6 + math.cos(progress * 2 * math.pi) * 0.15);
    canvas.drawCircle(center, ringRadius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';
import 'dart:math' as math;

// --- 1. خلفية التطبيق الحيوية العملاقة (AppBackground) ---
class AppBackground extends StatelessWidget {
  final Widget child;
  final String type;

  const AppBackground({
    super.key,
    required this.child,
    this.type = 'particles',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF070913),
            Color(0xFF0B0E1E),
            Color(0xFF05060C),
          ],
        ),
      ),
      child: Stack(
        children: [
          // إضاءات ضبابية خلفية لتعميق المشهد البصري
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D2FF).withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C5CE7).withOpacity(0.12),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// --- 2. الهالة المضيئة السائلة العضوية (AiOrbWidget) ---
enum OrbState { idle, thinking, speaking }

class AiOrbWidget extends StatefulWidget {
  final OrbState state;
  final double size;

  const AiOrbWidget({
    super.key,
    this.state = OrbState.idle,
    this.size = 180.0,
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
      duration: const Duration(seconds: 8),
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
    if (widget.state == OrbState.thinking) speedMultiplier = 2.4;
    if (widget.state == OrbState.speaking) speedMultiplier = 1.7;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = (_controller.value * speedMultiplier) % 1.0;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _FluidOrbPainter(
              progress: progress,
              state: widget.state,
            ),
          ),
        );
      },
    );
  }
}

class _FluidOrbPainter extends CustomPainter {
  final double progress;
  final OrbState state;

  _FluidOrbPainter({required this.progress, required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.38;
    final angle = progress * 2 * math.pi;

    // A. التوهج الخارجي الساطع العميق (Aura Glow)
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00D2FF).withOpacity(state == OrbState.thinking ? 0.45 : 0.28),
          const Color(0xFF6C5CE7).withOpacity(0.2),
          Colors.transparent,
        ],
        stops: const [0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.8))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    canvas.drawCircle(center, baseRadius * 1.6, auraPaint);

    // B. رسم الشكل العضوي السائل (Fluid Organic Blob Path)
    final path = Path();
    const int points = 360;

    for (int i = 0; i <= points; i++) {
      final theta = (i / points) * 2 * math.pi;

      // موجات هارمونية مركية تُنشئ الشكل المنساب العضوي
      double wave = math.sin(theta * 3 + angle * 2) * 0.12 +
          math.cos(theta * 2 - angle) * 0.08 +
          math.sin(theta * 5 + angle * 3) * 0.04;

      if (state == OrbState.thinking) {
        wave += math.sin(theta * 7 + angle * 5) * 0.07;
      } else if (state == OrbState.speaking) {
        wave += math.cos(theta * 4 + angle * 3) * 0.09;
      }

      final r = baseRadius * (1.0 + wave);
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // C. تدرج النواة السائلة الذكية (Liquid Mesh Gradient)
    final coreGradient = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(angle),
      colors: const [
        Color(0xFF20B2AA),
        Color(0xFF00D2FF),
        Color(0xFF3B82F6),
        Color(0xFF8B5CF6),
        Color(0xFFD946EF),
        Color(0xFF00D2FF),
      ],
      stops: const [0.0, 0.2, 0.45, 0.7, 0.88, 1.0],
    );

    final corePaint = Paint()
      ..shader = coreGradient.createShader(Rect.fromCircle(center: center, radius: baseRadius))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, corePaint);

    // D. انعكاس المركز المضيء العالي الانكسار (High-Specular Inner Highlight)
    final specularOffset = Offset(
      center.dx + math.cos(angle * 1.2) * (baseRadius * 0.22),
      center.dy + math.sin(angle * 1.2) * (baseRadius * 0.22),
    );

    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.95),
          Colors.white.withOpacity(0.25),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: specularOffset, radius: baseRadius * 0.55))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(specularOffset, baseRadius * 0.45, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _FluidOrbPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';
import 'dart:math' as math;

// --- 1. خلفية التطبيق الحيوية (AppBackground) ---
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
            Color(0xFF08090C),
            Color(0xFF0D0E15),
            Color(0xFF050608),
          ],
        ),
      ),
      child: child,
    );
  }
}

// --- 2. الهالة المضيئة التفاعلية (AiOrbWidget) ---
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
      duration: const Duration(seconds: 6),
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
    if (widget.state == OrbState.thinking) speedMultiplier = 2.2;
    if (widget.state == OrbState.speaking) speedMultiplier = 1.6;

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
    final baseRadius = size.width * 0.35;
    final angle = progress * 2 * math.pi;

    // 1. التوهج الخارجي الكبير (Ambient Background Glow)
    final outerGlowRadius = baseRadius * 1.8;
    final outerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2B52FF).withOpacity(state == OrbState.thinking ? 0.5 : 0.35),
          const Color(0xFF00D2FF).withOpacity(0.15),
          Colors.transparent,
        ],
        stops: const [0.2, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerGlowRadius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);

    canvas.drawCircle(center, outerGlowRadius, outerGlowPaint);

    // 2. النواة السائلة والتموجات الهارمونية (Liquid Dynamic Core)
    final path = Path();
    const int wavePoints = 180;
    final double pulse = math.sin(angle * 2) * 0.05;

    for (int i = 0; i <= wavePoints; i++) {
      final theta = (i / wavePoints) * 2 * math.pi;
      
      // معادلة التموج ثلاثية الأبعاد
      double waveModifier = math.sin(theta * 3 + angle) * 0.08 +
          math.cos(theta * 5 - angle * 2) * 0.04;

      if (state == OrbState.thinking) {
        waveModifier += math.sin(theta * 8 + angle * 4) * 0.06;
      } else if (state == OrbState.speaking) {
        waveModifier += math.cos(theta * 4 + angle * 3) * 0.09;
      }

      final r = baseRadius * (1.0 + pulse + waveModifier);
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // تدرج النواة الداخلي
    final coreGradient = SweepGradient(
      transform: GradientRotation(angle),
      colors: const [
        Color(0xFF2B52FF),
        Color(0xFF00D2FF),
        Color(0xFF6C5CE7),
        Color(0xFF00F2FE),
        Color(0xFF2B52FF),
      ],
    );

    final corePaint = Paint()
      ..shader = coreGradient.createShader(Rect.fromCircle(center: center, radius: baseRadius))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, corePaint);

    // 3. طبقة الضوء الساطع والعمق الزجاجي (Specular Energy Light)
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.35 + math.cos(angle) * 0.1, -0.35 + math.sin(angle) * 0.1),
        radius: 0.6,
        colors: [
          Colors.white.withOpacity(0.85),
          Colors.white.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, baseRadius * 0.85, highlightPaint);

    // 4. حلقات الطاقة المدارية (Orbital Energy Rings)
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        transform: GradientRotation(-angle * 1.5),
        colors: [
          Colors.white.withOpacity(0.8),
          const Color(0xFF00D2FF).withOpacity(0.3),
          Colors.transparent,
          Colors.white.withOpacity(0.6),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.2));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle * 0.5);
    canvas.scale(1.2, 0.85); // إعطاء شكل مداري بيضاوي
    canvas.drawCircle(Offset.zero, baseRadius * 0.95, ringPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.state != state;
  }
}

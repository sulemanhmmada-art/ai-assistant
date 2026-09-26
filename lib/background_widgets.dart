import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

// ============ 1. Particles (جزيئات بلورية) ============
class ParticlesBackground extends StatefulWidget {
  const ParticlesBackground({super.key});

  @override
  State<ParticlesBackground> createState() => _ParticlesBackgroundState();
}

class _ParticlesBackgroundState extends State<ParticlesBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 2 + _random.nextDouble() * 6,
        speed: 0.2 + _random.nextDouble() * 0.8,
        opacity: 0.2 + _random.nextDouble() * 0.5,
        color: _random.nextBool()
            ? const Color(0xFF764ba2)
            : const Color(0xFF10A37F),
      ));
    }
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
        return CustomPaint(
          painter: _ParticlesPainter(_particles, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlesPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final y = (p.y + (progress * p.speed)) % 1.0;
      final x = (p.x + math.sin(progress * 2 * math.pi + p.y * 10) * 0.05) % 1.0;

      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============ 2. Aurora (شفق قطبي) ============
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
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
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF0E1116), const Color(0xFF1A0E2E), t)!,
                Color.lerp(const Color(0xFF1A1A2E), const Color(0xFF2E1A4A), t)!,
                Color.lerp(const Color(0xFF16213E), const Color(0xFF1E2A5C), t)!,
                Color.lerp(const Color(0xFF0F3460), const Color(0xFF2A1A4A), t)!,
                const Color(0xFF0E1116),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ============ 3. Liquid Wave (موجات سائلة) ============
class LiquidWaveBackground extends StatefulWidget {
  const LiquidWaveBackground({super.key});

  @override
  State<LiquidWaveBackground> createState() => _LiquidWaveBackgroundState();
}

class _LiquidWaveBackgroundState extends State<LiquidWaveBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
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
        return CustomPaint(
          painter: _WavePainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  _WavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    // الخلفية الأساسية
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0E1116), Color(0xFF16213E)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 3 موجات
    for (int i = 0; i < 3; i++) {
      final phase = progress * 2 * math.pi + (i * math.pi / 3);
      final yOffset = size.height * (0.5 + i * 0.15);

      final path = Path();
      path.moveTo(0, yOffset);

      for (double x = 0; x <= size.width; x += 10) {
        final y = yOffset +
            math.sin((x / size.width) * 4 * math.pi + phase) * 30 +
            math.cos((x / size.width) * 2 * math.pi + phase * 1.5) * 15;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      final wavePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (i == 0
                    ? const Color(0xFF764ba2)
                    : i == 1
                        ? const Color(0xFF10A37F)
                        : const Color(0xFF0F3460))
                .withValues(alpha: 0.15),
            (i == 0
                    ? const Color(0xFF10A37F)
                    : i == 1
                        ? const Color(0xFF764ba2)
                        : const Color(0xFF1A1A2E))
                .withValues(alpha: 0.08),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============ 4. Gradient Flow (تدفق متدرج) ============
class GradientFlowBackground extends StatefulWidget {
  const GradientFlowBackground({super.key});

  @override
  State<GradientFlowBackground> createState() => _GradientFlowBackgroundState();
}

class _GradientFlowBackgroundState extends State<GradientFlowBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
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
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(math.cos(t * 2 * math.pi), math.sin(t * 2 * math.pi)),
              end: Alignment(-math.cos(t * 2 * math.pi), -math.sin(t * 2 * math.pi)),
              colors: const [
                Color(0xFF0E1116),
                Color(0xFF2E1A4A),
                Color(0xFF16213E),
                Color(0xFF0F3460),
                Color(0xFF0E1116),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ============ Wrapper لاختيار الخلفية ============
class AppBackground extends StatelessWidget {
  final String type;
  final Widget child;

  const AppBackground({
    super.key,
    required this.type,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Widget background;
    switch (type) {
      case 'aurora':
        background = const AuroraBackground();
        break;
      case 'wave':
        background = const LiquidWaveBackground();
        break;
      case 'gradient':
        background = const GradientFlowBackground();
        break;
      case 'particles':
      default:
        background = Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0E1116),
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                    Color(0xFF0E1116),
                  ],
                ),
              ),
            ),
            const ParticlesBackground(),
          ],
        );
    }

    return Stack(
      children: [
        Positioned.fill(child: background),
        Positioned.fill(child: child),
      ],
    );
  }
}

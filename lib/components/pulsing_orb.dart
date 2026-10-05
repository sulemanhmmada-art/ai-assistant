import 'dart:math' as math;
import 'package:flutter/material.dart';

enum OrbState { idle, listening, processing }

class PulsingOrb extends StatefulWidget {
  final OrbState state;
  const PulsingOrb({super.key, required this.state});

  @override
  State<PulsingOrb> createState() => _PulsingOrbState();
}

class _PulsingOrbState extends State<PulsingOrb> with SingleTickerProviderStateMixin {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double speedMultiplier = widget.state == OrbState.processing ? 2.5 : 1.0;
        double scale = widget.state == OrbState.listening 
            ? 1.15 + math.sin(_controller.value * math.pi * 4) * 0.05 
            : 1.0 + math.sin(_controller.value * math.pi * 2) * 0.03;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: _getOrbColors(),
                stops: const [0.2, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getOrbColors()[0].withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Color> _getOrbColors() {
    switch (widget.state) {
      case OrbState.listening:
        return [const Color(0xFFFF0055), const Color(0xFF7000FF), Colors.transparent];
      case OrbState.processing:
        return [const Color(0xFF00FFCC), const Color(0xFF0077FF), Colors.transparent];
      case OrbState.idle:
      default:
        return [const Color(0xFF00F0FF), const Color(0xFF7000FF), Colors.transparent];
    }
  }
}

import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
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
          painter: _ParticlePainter(
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final double progress;

  _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final paint = Paint();
    const particleCount = 35;

    for (int i = 0; i < particleCount; i++) {
      final seedX = rng.nextDouble();
      final seedY = rng.nextDouble();
      final particleSize = 1.5 + rng.nextDouble() * 3.5;
      final speed = 0.15 + rng.nextDouble() * 0.65;
      final baseOpacity = 0.08 + rng.nextDouble() * 0.22;

      final y = ((seedY - progress * speed) % 1.0);
      final wrappedY = y < 0 ? y + 1.0 : y;

      final x = ((seedX + progress * speed * 0.3) % 1.0);

      paint.color = Colors.white.withOpacity(baseOpacity);
      paint.style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x * size.width, wrappedY * size.height),
        particleSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

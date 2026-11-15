import 'package:flutter/material.dart';
import 'dart:math' as math;

class LaLaLandBackground extends StatelessWidget {
  final Widget child;
  const LaLaLandBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: LaLaLandPainter(),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class LaLaLandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Twilight Gradient Sky (City of Stars purple/indigo gradient)
    final Rect rect = Offset.zero & size;
    final Paint skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF040612), // Deep Starry Night Sky
          Color(0xFF140E36), // Deep Indigo
          Color(0xFF381F6D), // Twilight Purple
          Color(0xFF0C0A18), // Horizon Night
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, skyPaint);

    // 2. Stars
    final Paint starPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final random = math.Random(42);
    for (int i = 0; i < 80; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * (size.height * 0.72);
      double radius = random.nextDouble() * 1.8 + 0.4;
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }

    // 3. City Skyline Lights at Horizon
    final double horizonY = size.height * 0.78;
    final Paint cityPaint = Paint()..color = const Color(0xFFFFD166).withValues(alpha: 0.65);
    final Paint cityGlow = Paint()..color = const Color(0xFF00F0FF).withValues(alpha: 0.15);

    canvas.drawRect(Rect.fromLTRB(0, horizonY - 6, size.width, size.height), cityGlow);

    for (int i = 0; i < 140; i++) {
      double cx = (i / 140.0) * size.width + (random.nextDouble() * 4 - 2);
      double cy = horizonY + random.nextDouble() * (size.height - horizonY);
      canvas.drawCircle(Offset(cx, cy), random.nextDouble() * 1.5 + 0.5, cityPaint);
    }

    // 4. Iconic Streetlamp Warm Glow on the Right
    final Offset lampCenter = Offset(size.width * 0.88, size.height * 0.68);
    final Paint lampGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFBE8).withValues(alpha: 0.95),
          const Color(0xFFFFD166).withValues(alpha: 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: lampCenter, radius: 140));

    canvas.drawCircle(lampCenter, 140, lampGlow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

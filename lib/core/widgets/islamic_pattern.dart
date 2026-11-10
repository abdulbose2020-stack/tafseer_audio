import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A subtle, scalable geometric background inspired by Islamic tilework.
///
/// The pattern is painted rather than bundled as an image so it stays crisp
/// at every screen density and can adapt to the current theme color.
class IslamicPattern extends StatelessWidget {
  const IslamicPattern({
    super.key,
    this.color = Colors.white,
    this.opacity = 0.08,
    this.spacing = 56,
    this.strokeWidth = 1,
    this.child,
  });

  final Color color;
  final double opacity;
  final double spacing;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IslamicPatternPainter(
        color: color.withValues(alpha: opacity),
        spacing: spacing,
        strokeWidth: strokeWidth,
      ),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  const _IslamicPatternPainter({
    required this.color,
    required this.spacing,
    required this.strokeWidth,
  });

  final Color color;
  final double spacing;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final starSize = spacing * 0.22;

    for (double y = spacing / 2; y < size.height + spacing; y += spacing) {
      for (double x = spacing / 2; x < size.width + spacing; x += spacing) {
        _drawStar(canvas, Offset(x, y), starSize, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.drawRect(
      Rect.fromCenter(center: center, width: size, height: size),
      paint,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IslamicPatternPainter oldDelegate) {
    return color != oldDelegate.color ||
        spacing != oldDelegate.spacing ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}

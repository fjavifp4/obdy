import 'package:flutter/material.dart';

class BackgroundPattern extends CustomPainter {
  final Color color;
  final double opacity;

  BackgroundPattern({
    required this.color,
    this.opacity = 0.03,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    const spacing = 20.0;
    
    // Dibujar líneas horizontales
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Dibujar líneas verticales
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BackgroundPattern oldDelegate) =>
      color != oldDelegate.color || opacity != oldDelegate.opacity;
} 
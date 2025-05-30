import 'package:flutter/material.dart';

class AuthBackgroundPainter extends CustomPainter {
  final Color primaryColor;

  AuthBackgroundPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Pintar el fondo completo con un color más claro
    final Paint backgroundPaint = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );

    // Pintar la forma superior con el color primario
    final Paint paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.3);
    path.lineTo(0, size.height * 0.4);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthCardPainter extends CustomPainter {
  final bool isDarkMode;
  
  AuthCardPainter({this.isDarkMode = false});
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = isDarkMode ? const Color(0xFF2A2A2D) : Colors.white
      ..style = PaintingStyle.fill;

    final double radius = 20.0; // Radio de las esquinas redondeadas
    final Path path = Path();
    
    // Esquina superior izquierda redondeada
    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    
    // Línea diagonal hacia la derecha con curva
    path.lineTo(size.width - radius, size.height * 0.1);
    path.quadraticBezierTo(
      size.width, 
      size.height * 0.1,
      size.width,
      size.height * 0.1 + radius
    );
    
    // Línea recta hacia abajo
    path.lineTo(size.width, size.height - radius);
    
    // Esquina inferior derecha redondeada
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - radius,
      size.height
    );
    
    // Línea recta hacia la izquierda
    path.lineTo(radius, size.height);
    
    // Esquina inferior izquierda redondeada
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    
    path.close();

    // Añadir sombra
    canvas.drawShadow(path, Colors.black.withOpacity(0.3), 8.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 

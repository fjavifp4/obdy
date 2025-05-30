import 'package:flutter/material.dart';
import 'dart:math' as math;

class BackgroundPattern extends CustomPainter {
  final Color color;
  final double opacity;

  BackgroundPattern({
    required this.color,
    this.opacity = 0.03,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dibujamos el patrón ondulado con gradientes
    _drawWavyGradientBackground(canvas, size);
  }

  void _drawWavyGradientBackground(Canvas canvas, Size size) {
    // Colores primarios y variantes para los gradientes
    final primaryColor = color;
    final lightVariant = primaryColor.withOpacity(0.03);
    final midVariant = primaryColor.withOpacity(0.08);
    final darkVariant = primaryColor.withOpacity(0.15);
    
    // Parámetros para las ondas
    final double waveHeight = size.height * 0.06;  // Altura de las ondas
    final double waveFrequency = 0.015;            // Frecuencia de las ondas
    final double wavePhase = 0;                    // Fase inicial

    // Creamos tres conjuntos de ondas para el fondo
    
    // 1. Onda superior - más oscura en la parte superior
    _drawTopWaveGradient(canvas, size, waveHeight, waveFrequency, wavePhase, darkVariant, lightVariant);
    
    // 2. Onda inferior - más oscura en la parte inferior
    _drawBottomWaveGradient(canvas, size, waveHeight, waveFrequency, wavePhase + math.pi / 2, darkVariant, lightVariant);
    
    // 3. Ondas medias decorativas
    _drawDecorativeWaves(canvas, size, midVariant.withOpacity(0.04));
  }

  void _drawTopWaveGradient(Canvas canvas, Size size, double waveHeight, double waveFrequency, 
      double wavePhase, Color topColor, Color bottomColor) {
    
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 0.5);
    
    final wavyPath = Path();
    wavyPath.moveTo(0, 0); // Comenzar desde la esquina superior izquierda
    
    // Agregar la parte superior del lienzo
    wavyPath.lineTo(size.width, 0);
    
    // Crear la curva ondulada para el borde inferior
    final bottomY = size.height * 0.4; // La onda termina al 40% de la altura
    
    for (double x = 0; x <= size.width; x += 1) {
      final waveY = bottomY + 
          math.sin((x * waveFrequency) + wavePhase) * waveHeight;
      wavyPath.lineTo(x, waveY);
    }
    
    // Completar el camino cerrándolo
    wavyPath.lineTo(0, bottomY);
    wavyPath.close();
    
    // Crear un gradiente linear para que sea más oscuro arriba y se desvanezca hacia abajo
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [topColor, bottomColor],
      stops: const [0.0, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(wavyPath, paint);
  }

  void _drawBottomWaveGradient(Canvas canvas, Size size, double waveHeight, double waveFrequency, 
      double wavePhase, Color bottomColor, Color topColor) {
    
    final rect = Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5);
    
    final wavyPath = Path();
    
    // Crear la curva ondulada para el borde superior
    final topY = size.height * 0.6; // La onda comienza al 60% de la altura
    wavyPath.moveTo(0, topY);
    
    for (double x = 0; x <= size.width; x += 1) {
      final waveY = topY + 
          math.sin((x * waveFrequency) + wavePhase) * waveHeight;
      wavyPath.lineTo(x, waveY);
    }
    
    // Completar el resto del rectángulo
    wavyPath.lineTo(size.width, size.height);
    wavyPath.lineTo(0, size.height);
    wavyPath.close();
    
    // Crear un gradiente linear para que sea más oscuro abajo y se desvanezca hacia arriba
    final gradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [bottomColor, topColor],
      stops: const [0.0, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(wavyPath, paint);
  }

  void _drawDecorativeWaves(Canvas canvas, Size size, Color waveColor) {
    final wavePaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..isAntiAlias = true;
    
    // Parámetros para ondas decorativas
    const int numWaves = 5;
    final double spacing = size.height / (numWaves + 1);
    
    for (int i = 1; i <= numWaves; i++) {
      final centerY = spacing * i;
      final path = Path();
      
      // Características de las ondas
      final amplitude = size.height * 0.02;
      final frequency = 0.02;
      final phase = i * math.pi / numWaves; // Fase diferente para cada onda
      
      path.moveTo(0, centerY);
      
      for (double x = 0; x <= size.width; x += 1) {
        final y = centerY + math.sin((x * frequency) + phase) * amplitude;
        path.lineTo(x, y);
      }
      
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(BackgroundPattern oldDelegate) =>
      color != oldDelegate.color || opacity != oldDelegate.opacity;
} 

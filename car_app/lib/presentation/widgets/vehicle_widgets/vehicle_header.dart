import 'package:flutter/material.dart';
import 'dart:convert';

class VehicleHeader extends StatelessWidget {
  final String brand;
  final String model;
  final int year;
  final String? logoBase64;

  const VehicleHeader({
    super.key,
    required this.brand,
    required this.model,
    required this.year,
    this.logoBase64,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
            Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          // Decoración visual (puntos o elementos gráficos de fondo)
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: DotPatternPainter(),
              ),
            ),
          ),
          
          // Contenido
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo o imagen del vehículo
                if (logoBase64 != null)
                  Center(
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.memory(
                        base64Decode(logoBase64!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                if (logoBase64 == null)
                  Center(
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_car,
                        size: 60,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 15),
                
                // Nombre del vehículo
                Center(
                  child: Text(
                    '$brand $model',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Año del vehículo
                Center(
                  child: Text(
                    year.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    const dotSize = 2.0;
    const spacing = 20.0;
    
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(
          Offset(x, y),
          dotSize / 2,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 
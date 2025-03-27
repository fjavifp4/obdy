import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';

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
    final theme = Theme.of(context);
    final isDarkMode = context.watch<ThemeBloc>().state;
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode 
              ? [
                  Color(0xFF2A2A2D),
                  Color(0xFF2A2A2D).withOpacity(0.0),
                ]
              : [
                  theme.colorScheme.primary.withOpacity(1),
                  theme.colorScheme.primary.withOpacity(.0),
                ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.zero,
          bottomRight: Radius.zero,
        ),
      ),
      child: Stack(
        children: [
          // Decoración visual (puntos o elementos gráficos de fondo)
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: DotPatternPainter(
                  dotColor: isDarkMode 
                      ? Colors.white 
                      : theme.colorScheme.onPrimary,
                ),
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
                        color: isDarkMode 
                            ? Color(0xFF3A3A3D)
                            : theme.colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow,
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
                        color: isDarkMode 
                            ? Color(0xFF3A3A3D)
                            : theme.colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow,
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_car,
                        size: 60,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 15),
                
                // Nombre del vehículo
                Center(
                  child: Text(
                    '$brand $model',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isDarkMode 
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onPrimary,
                      shadows: [
                        Shadow(
                          color: theme.colorScheme.shadow,
                          blurRadius: 2,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Año del vehículo
                /*Center(
                  child: Text(
                    year.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w300,
                      shadows: [
                        Shadow(
                          color: theme.colorScheme.shadow,
                          blurRadius: 2,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),*/
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DotPatternPainter extends CustomPainter {
  final Color dotColor;
  
  DotPatternPainter({
    required this.dotColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = dotColor.withOpacity(0.4)
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
  bool shouldRepaint(covariant DotPatternPainter oldDelegate) => 
    oldDelegate.dotColor != dotColor;
} 
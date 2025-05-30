import 'package:flutter/material.dart';
import '../../config/theme/background_pattern.dart';

class BackgroundContainer extends StatelessWidget {
  final Widget child;
  final double patternOpacity;

  const BackgroundContainer({
    super.key,
    required this.child,
    this.patternOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: colorScheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: BackgroundPattern(
                  color: colorScheme.primary,
                  opacity: patternOpacity,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
} 

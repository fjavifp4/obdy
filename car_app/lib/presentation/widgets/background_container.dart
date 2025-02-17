import 'package:flutter/material.dart';
import '../../config/theme/background_pattern.dart';

class BackgroundContainer extends StatelessWidget {
  final Widget child;

  const BackgroundContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPattern(
                color: Theme.of(context).colorScheme.onBackground,
                opacity: 0.03,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
} 
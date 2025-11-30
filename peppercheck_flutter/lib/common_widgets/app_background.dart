import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Paper texture background
        Positioned.fill(
          child: Image.asset(
            'assets/images/paper_texture.jpg',
            fit: BoxFit.cover,
          ),
        ),
        // Semi-transparent overlay to lighten the texture
        Positioned.fill(
          child: Container(
            color: AppColors.backgroundWhite.withValues(alpha: 0.2),
          ),
        ),
        // Content
        Positioned.fill(child: child),
      ],
    );
  }
}

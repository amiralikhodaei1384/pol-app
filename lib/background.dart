import 'dart:ui';
import 'package:flutter/material.dart';

/// Blurred gradient background used behind pages.
class ElegantBackground extends StatelessWidget {
  final Widget child;

  const ElegantBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFFF8FAFC)),

        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0072FF).withOpacity(0.4),
            ),
          ),
        ),

        Positioned(
          bottom: -100,
          left: -100,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withOpacity(0.35),
            ),
          ),
        ),

        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              color: Colors.white.withOpacity(0.45),
            ),
          ),
        ),

        child,
      ],
    );
  }
}
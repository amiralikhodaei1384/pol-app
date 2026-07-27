import 'package:flutter/material.dart';
import 'dart:math' as math;

class RotatingGradientBorder extends StatefulWidget {
  final Widget child;
  final double borderRadius;

  const RotatingGradientBorder({
    super.key,
    required this.child,
    this.borderRadius = 32,
  });

  @override
  State<RotatingGradientBorder> createState() => _RotatingGradientBorderState();
}

class _RotatingGradientBorderState extends State<RotatingGradientBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0072FF).withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _GradientPainter(
              angle: _controller.value * 2 * math.pi,
              borderRadius: widget.borderRadius,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _GradientPainter extends CustomPainter {
  final double angle;
  final double borderRadius;

  _GradientPainter({required this.angle, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFF0072FF), // آبی
          Color(0xFF10B981), // سبز
          Color(0xFF0072FF), // آبی
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(angle),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    canvas.drawRRect(path, paint);
  }

  @override
  bool shouldRepaint(_GradientPainter oldDelegate) => angle != oldDelegate.angle;
}
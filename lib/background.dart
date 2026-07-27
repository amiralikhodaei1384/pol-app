import 'dart:ui';
import 'package:flutter/material.dart';

class ElegantBackground extends StatelessWidget {
  final Widget child;

  const ElegantBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ۱. رنگ پایه پس‌زمینه
        Container(color: const Color(0xFFF8FAFC)),

        // ۲. هاله نوری آبی (بزرگ‌تر و واضح‌تر در بالا سمت راست)
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 500, // قطر ۵۰۰ پیکسل برای پخش شدن بیشتر رنگ در صفحه
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0072FF).withOpacity(0.4), // غلظت بیشتر رنگ آبی
            ),
          ),
        ),

        // ۳. هاله نوری سبز (بزرگ‌تر و واضح‌تر در پایین سمت چپ)
        Positioned(
          bottom: -100,
          left: -100,
          child: Container(
            width: 500, // قطر ۵۰۰ پیکسل برای پوشش وسیع‌تر
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withOpacity(0.35), // غلظت بیشتر رنگ سبز
            ),
          ),
        ),

        // ۴. فیلتر مات‌کننده برای ایجاد افکت گرادینت ابری (Mesh Gradient) بسیار نرم
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              // غلظت لایه سفید روی هاله‌ها را به ۴۵٪ کاهش دادیم تا رنگ‌های زیرین به خوبی نمایان شوند
              color: Colors.white.withOpacity(0.45),
            ),
          ),
        ),

        // ۵. قرارگیری محتوای اصلی
        child,
      ],
    );
  }
}
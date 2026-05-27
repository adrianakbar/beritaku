import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? glassColor;
  final List<BoxShadow>? shadows;
  final Border? customBorder;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 25.0,
    this.opacity = 0.35, // More opaque white base for Light Milky Glass look
    this.borderOpacity = 0.45, // Crisp metallic crystal border refraction
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.glassColor,
    this.shadows,
    this.customBorder,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows ?? [
          // Soft ambient grey shadow for 3D depth on light backgrounds
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          // Subtle white ambient glow
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: glassColor ?? Colors.white.withOpacity(opacity),
              border: customBorder ?? Border.all(
                color: Colors.white.withOpacity(borderOpacity),
                width: 1.5, // Thicker crystalline borders
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(opacity + 0.15),
                  Colors.white.withOpacity(opacity),
                  Colors.white.withOpacity(opacity - 0.12 >= 0 ? opacity - 0.12 : 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

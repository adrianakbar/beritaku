import 'package:flutter/material.dart';
import 'glass_container.dart';

class GlassShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const GlassShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16.0,
  });

  @override
  State<GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<GlassShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return GlassContainer(
          width: widget.width,
          height: widget.height,
          borderRadius: widget.borderRadius,
          padding: EdgeInsets.zero,
          opacity: 0.05,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    transform: _SlidingGradientTransform(_animation.value),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double width = bounds.width;
    final double translation = width * slidePercent;
    return Matrix4.translationValues(translation, 0.0, 0.0);
  }
}

// Beautiful glowing Sentiment / Category Badge
class SentimentBadge extends StatelessWidget {
  final String? category;
  final bool compact;

  const SentimentBadge({
    super.key,
    required this.category,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (category == null || category!.isEmpty) return const SizedBox.shrink();

    // Map Category to Theme
    final String cat = category!.trim();
    IconData icon = Icons.newspaper_rounded;
    Color glowColor = const Color(0xFF94A3B8); // Gray
    String label = cat;
    
    if (cat == 'Politik Memanas') {
      icon = Icons.local_fire_department_rounded;
      glowColor = const Color(0xFFEF4444); // Red
      label = 'Politik Memanas';
    } else if (cat == 'Ekonomi Makro') {
      icon = Icons.trending_up_rounded;
      glowColor = const Color(0xFF3B82F6); // Blue
      label = 'Ekonomi Makro';
    } else if (cat == 'Sains & Teknologi') {
      icon = Icons.bolt_rounded;
      glowColor = const Color(0xFF10B981); // Green/Emerald
      label = 'Sains & Tekno';
    } else if (cat == 'Gosip Ringan') {
      icon = Icons.chat_bubble_outline_rounded;
      glowColor = const Color(0xFFF59E0B); // Amber
      label = 'Gosip Ringan';
    } else if (cat == 'Berita Umum') {
      icon = Icons.newspaper_rounded;
      glowColor = const Color(0xFF06B6D4); // Cyan
      label = 'Berita Umum';
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: glowColor.withOpacity(0.12),
          border: Border.all(color: glowColor.withOpacity(0.3), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: glowColor, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: glowColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: glowColor.withOpacity(0.1),
        border: Border.all(color: glowColor.withOpacity(0.35), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: -2,
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: glowColor, size: 16),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              shadows: [
                Shadow(
                  color: glowColor.withOpacity(0.8),
                  blurRadius: 6,
                )
              ]
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';

class LiquidBackground extends StatefulWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 30 seconds slow rotation for high performance and premium feeling
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // Pristine light pearlescent background for Light Mode
      body: Stack(
        children: [
          // Ambient organic pastel liquid blobs
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final angle = _controller.value * 2 * pi;
              
              // Organic path coordinates
              final x1 = sin(angle) * 50;
              final y1 = cos(angle) * 80;
              
              final x2 = cos(angle + pi/3) * 60;
              final y2 = sin(angle + pi/3) * 70;
              
              final x3 = sin(angle + 2*pi/3) * 80;
              final y3 = cos(angle + 2*pi/3) * 50;

              return Stack(
                children: [
                  // Blob 1: Soft Lilac Pastel
                  Positioned(
                    top: size.height * 0.15 + y1,
                    left: size.width * 0.1 + x1,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFD8B4FE).withOpacity(0.4), // Soft Lilac
                            const Color(0xFFD8B4FE).withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Blob 2: Soft Creamy Peach Pastel
                  Positioned(
                    bottom: size.height * 0.2 + y2,
                    right: size.width * 0.05 + x2,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFDBA74).withOpacity(0.4), // Soft Peach
                            const Color(0xFFFDBA74).withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Blob 3: Soft Sky Blue / Mint Pastel
                  Positioned(
                    top: size.height * 0.5 + y3,
                    left: size.width * 0.3 + x3,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFBAE6FD).withOpacity(0.45), // Soft Sky Blue
                            const Color(0xFFBAE6FD).withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // The application content laid on top of the liquid background
          SafeArea(
            bottom: false,
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

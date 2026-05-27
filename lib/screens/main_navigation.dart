import 'package:flutter/material.dart';
import '../widgets/liquid_background.dart';
import '../widgets/glass_container.dart';
import 'dashboard_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const BookmarksScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LiquidBackground(
      child: Stack(
        children: [
          // Current Screen
          Padding(
            padding: const EdgeInsets.only(bottom: 90.0), // Give room for floating nav bar
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
          
          // Floating Liquid Glass Navigation Bar
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: GlassContainer(
              blur: 30,
              opacity: 0.08,
              borderOpacity: 0.2,
              borderRadius: 30.0,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.grid_view_rounded, 'Beranda'),
                  _buildNavItem(1, Icons.bookmarks_rounded, 'Simpanan'),
                  _buildNavItem(2, Icons.tune_rounded, 'Setelan'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = _currentIndex == index;
    final Color activeColor = const Color(0xFF6366F1); // Indigo Glow
    final Color inactiveColor = Colors.white.withOpacity(0.5);

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                icon,
                color: isActive ? activeColor : inactiveColor,
                size: isActive ? 26 : 24,
                shadows: isActive 
                    ? [
                        Shadow(
                          color: activeColor.withOpacity(0.6),
                          blurRadius: 10,
                        )
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : inactiveColor,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            // Glowing Indicator Dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? 5 : 0,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeColor,
                boxShadow: [
                  BoxShadow(
                    color: activeColor,
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              ),
            )
          ],
        ),
      ),
    );
  }
}

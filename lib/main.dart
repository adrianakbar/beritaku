import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/main_navigation.dart';
import 'screens/login_screen.dart';

void main() async {
  // Ensure Flutter engine is initialized before starting services
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage local database & settings
  final StorageService storage = StorageService();
  await storage.init();

  // Initialize notification reminder service
  final NotificationService notifications = NotificationService();
  await notifications.init();

  // Force portrait orientation and set translucent status bar overlay for light backgrounds
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for light theme
      systemNavigationBarColor: Color(0xFFF5F6FA),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Check login session
  final AuthService auth = AuthService();
  final bool isLoggedIn = await auth.isSessionActive();

  runApp(BeritakuApp(isLoggedIn: isLoggedIn));
}

class BeritakuApp extends StatelessWidget {
  final bool isLoggedIn;
  const BeritakuApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beritaku AI',
      debugShowCheckedModeBanner: false,
      
      // Light Theme configuration as foundation for Milky Liquid Glass
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F6FA), // Cream light pearlescent
        primaryColor: const Color(0xFF6366F1), // Electric Indigo Accent
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF818CF8),
          surface: Colors.white,
          background: Color(0xFFF5F6FA),
          error: Colors.redAccent,
        ),
        
        // Premium Typography (Poppins)
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        
        appBarTheme: AppBarTheme(
          color: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)), // Dark icons for light bar
          titleTextStyle: GoogleFonts.poppins(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          )
        ),
        
        // Custom sliders for TTS speed & pitch
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFF6366F1),
          thumbColor: const Color(0xFF6366F1),
          overlayColor: const Color(0xFF6366F1).withOpacity(0.2),
          trackHeight: 4.0,
        ),
      ),
      home: isLoggedIn ? const MainNavigation() : const LoginScreen(),
    );
  }
}

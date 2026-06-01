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

class BeritakuApp extends StatefulWidget {
  final bool isLoggedIn;
  const BeritakuApp({super.key, required this.isLoggedIn});

  static _BeritakuAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_BeritakuAppState>();

  @override
  State<BeritakuApp> createState() => _BeritakuAppState();
}

class _BeritakuAppState extends State<BeritakuApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  void _loadThemeMode() {
    final modeStr = StorageService().getThemeMode();
    _updateThemeMode(modeStr);
  }

  void _updateThemeMode(String modeStr) {
    setState(() {
      if (modeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (modeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
  }

  void changeTheme(String modeStr) {
    StorageService().setThemeMode(modeStr);
    _updateThemeMode(modeStr);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beritaku AI',
      debugShowCheckedModeBanner: false,
      
      themeMode: _themeMode,
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
        
        // Premium Typography (Outfit for Headers/Display + Plus Jakarta Sans for Body)
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
          displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
          displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
          displaySmall: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
          headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
          headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          headlineSmall: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
          titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
          titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          titleSmall: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        
        appBarTheme: AppBarTheme(
          color: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)), // Dark icons for light bar
          titleTextStyle: GoogleFonts.outfit(
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
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Premium Slate 900
        primaryColor: const Color(0xFF6366F1), // Electric Indigo Accent
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1E293B), // Slate 800
          background: Color(0xFF0F172A),
          error: Colors.redAccent,
        ),
        
        // Premium Typography (Outfit for Headers/Display + Plus Jakarta Sans for Body)
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
          displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
          displaySmall: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
          headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
          headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white),
          headlineSmall: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
          titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
          titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white),
          titleSmall: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        
        appBarTheme: AppBarTheme(
          color: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: Colors.white), // Light icons for dark bar
          titleTextStyle: GoogleFonts.outfit(
            color: Colors.white,
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
      home: const LoginScreen(),
    );
  }
}

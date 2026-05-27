import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Keys for SharedPreferences
  static const String _keyUserRegistered = 'auth_user_registered';
  static const String _keyUserName = 'auth_user_name';
  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyUserPassword = 'auth_user_password';
  static const String _keySessionActive = 'auth_session_active';
  static const String _keyBiometricEnabled = 'auth_biometric_enabled';

  // Check if any user is registered
  Future<bool> isUserRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUserRegistered) ?? false;
  }

  // Get registered user name
  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? 'Adrian';
  }

  // Get registered user email
  Future<String> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail) ?? '';
  }

  // Register a new user
  Future<bool> registerUser(String name, String email, String password) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) return false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email.trim().toLowerCase());
    await prefs.setString(_keyUserPassword, password);
    await prefs.setBool(_keyUserRegistered, true);
    
    // Auto login session on register
    await prefs.setBool(_keySessionActive, true);
    
    // Default: enable biometric on register if device supports it
    final canBio = await isBiometricSupported();
    await prefs.setBool(_keyBiometricEnabled, canBio);

    return true;
  }

  // Standard Login verification
  Future<bool> loginUser(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    
    final registeredEmail = prefs.getString(_keyUserEmail) ?? '';
    final registeredPassword = prefs.getString(_keyUserPassword) ?? '';

    if (email.trim().toLowerCase() == registeredEmail && password == registeredPassword) {
      await prefs.setBool(_keySessionActive, true);
      return true;
    }
    return false;
  }

  // Logout session
  Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySessionActive, false);
  }

  // Check if session is currently active
  Future<bool> isSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySessionActive) ?? false;
  }

  // Check if biometric is enabled by user in settings
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  Future<void> setBiometricEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, val);
  }

  // Check if the current device hardware supports biometric scanning
  Future<bool> isBiometricSupported() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  // Perform Native Biometric Authentication (Fingerprint or FaceID)
  // Returns true on success, false on fail or fallback simulation needed
  Future<bool> authenticateWithBiometrics() async {
    final bool supported = await isBiometricSupported();
    if (!supported) return false; // Hardware doesn't support biometrics

    try {
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      String reason = 'Silakan pindai sidik jari atau wajah Anda untuk masuk ke Beritaku';
      if (availableBiometrics.contains(BiometricType.face)) {
        reason = 'Silakan pindai Face ID Anda untuk masuk ke Beritaku';
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true, // Only allow biometrics (fingerprint/face), no pin fallback
          stickyAuth: true,    // Keep scanning active if app goes to background
        ),
      );
      
      if (didAuthenticate) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keySessionActive, true);
      }
      return didAuthenticate;
    } on PlatformException catch (_) {
      // Platform failure (e.g. not enrolled or locked out). Fallback gracefully.
      return false;
    } catch (_) {
      return false;
    }
  }
}

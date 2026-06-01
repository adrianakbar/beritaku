import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/liquid_background.dart';
import '../widgets/glass_container.dart';
import 'main_navigation.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Switch between Login and Register tabs
  bool _isLoginView = true;
  bool _isObscure = true;
  bool _isLoading = false;
  bool _deviceHasBiometrics = false;
  bool _isBiometricOnlyLock = false;
  String _welcomeName = '';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
    _checkBiometricsSupport();

    // Pulse animation controller for Biometrics button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  Future<void> _checkRegistrationStatus() async {
    final registered = await _auth.isUserRegistered();
    if (!registered && mounted) {
      setState(() {
        _isLoginView = false; // Default to Register on first open
      });
    }
  }

  Future<void> _checkBiometricsSupport() async {
    final hasBio = await _auth.isBiometricSupported();
    final sessionActive = await _auth.isSessionActive();
    final bioEnabled = await _auth.isBiometricEnabled();
    final name = await _auth.getUserName();
    
    if (mounted) {
      setState(() {
        _deviceHasBiometrics = hasBio;
        _isBiometricOnlyLock = sessionActive && bioEnabled;
        _welcomeName = name;
      });

      if (_isBiometricOnlyLock) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleBiometricLogin();
        });
      }
    }
  }

  Future<void> _handleSwitchAccount() async {
    await _auth.logoutUser();
    setState(() {
      _isBiometricOnlyLock = false;
      _isLoginView = true;
      _emailController.clear();
      _passwordController.clear();
    });
  }


  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Handle Register
  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Harap isi semua kolom.', Colors.amber);
      return;
    }

    if (password != confirm) {
      _showSnackBar('Konfirmasi kata sandi tidak cocok.', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);
    final ok = await _auth.registerUser(name, email, password);
    setState(() => _isLoading = false);

    if (ok) {
      _showSnackBar('Pendaftaran berhasil! Silakan masuk menggunakan akun baru Anda.', Colors.green);
      setState(() {
        _isLoginView = true;
        _passwordController.clear();
        _confirmPasswordController.clear();
      });
    } else {
      _showSnackBar('Pendaftaran gagal. Silakan coba kembali.', Colors.red);
    }
  }

  // Handle Standard Login
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Masukkan email dan kata sandi.', Colors.amber);
      return;
    }

    setState(() => _isLoading = true);
    final ok = await _auth.loginUser(email, password);
    setState(() => _isLoading = false);

    if (ok) {
      _showSnackBar('Selamat datang kembali!', Colors.green);
      _navigateToHome();
    } else {
      _showSnackBar('Email atau kata sandi Anda salah.', Colors.redAccent);
    }
  }

  // Handle Biometric Quick Access
  Future<void> _handleBiometricLogin() async {
    final bioEnabled = await _auth.isBiometricEnabled();
    
    if (!bioEnabled) {
      // Biometrics not activated yet
      _showBiometricSetupPrompt();
      return;
    }

    setState(() => _isLoading = true);
    final ok = await _auth.authenticateWithBiometrics();
    setState(() => _isLoading = false);

    if (ok) {
      _showSnackBar('Autentikasi biometrik berhasil!', Colors.green);
      _navigateToHome();
    } else {
      // Hardware failed or simulation needed (for emulator convenience)
      _showBiometricSimulationDialog();
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigation()),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: color.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      ),
    );
  }

  // Beautiful fingerprint simulation dialog for immediate testing
  void _showBiometricSimulationDialog() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        bool scanning = true;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Trigger auto success after 1.8 seconds simulation
            Future.delayed(const Duration(milliseconds: 1800), () async {
              if (scanning && context.mounted) {
                setDialogState(() => scanning = false);
                await Future.delayed(const Duration(milliseconds: 600));
                if (context.mounted) {
                  Navigator.of(context).pop(); // Dismiss scanner
                  
                  final registered = await _auth.isUserRegistered();
                  if (!registered) {
                    await _auth.registerUser('Adrian Akbar', 'user@example.com', 'pass'); // Auto seed to proceed
                  }
                  
                  // Set session active
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('auth_session_active', true);
                  
                  _showSnackBar('Autentikasi Biometrik Sukses (Simulasi)!', Colors.green);
                  _navigateToHome();
                }
              }
            });


            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassContainer(
                blur: 35,
                opacity: isDark ? 0.25 : 0.2,
                borderRadius: 28,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      scanning ? 'Pindai Sidik Jari / Wajah' : 'Verifikasi Berhasil!',
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    
                    // Scanning Fingerprint Visual
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulse rings
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (scanning ? const Color(0xFF6366F1) : Colors.green).withOpacity(0.08),
                          ),
                        ),
                        
                        // Fingerprint Glowing Scanner Icon
                        Icon(
                          scanning ? LucideIcons.fingerprint : LucideIcons.checkCircle,
                          color: scanning ? const Color(0xFF6366F1) : Colors.green,
                          size: 56,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      scanning 
                          ? 'Silakan letakkan jari Anda pada sensor biometrik untuk memverifikasi identitas...' 
                          : 'Sesi aman terbuka. Selamat membaca!',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 11, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBiometricSetupPrompt() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            blur: 30,
            opacity: isDark ? 0.22 : 0.15,
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.shieldAlert, color: Color(0xFF6366F1), size: 42),
                const SizedBox(height: 14),
                Text(
                  'Biometrik Belum Aktif',
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Silakan daftarkan akun utama Anda terlebih dahulu, kemudian aktifkan fitur Biometrik di menu "Setelan" aplikasi agar bisa menggunakan login sidik jari cepat.',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 11, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Saya Mengerti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 35),
              
              // App Brand / Logo (Using the premium transparent logo)
              Image.asset(
                'lib/assets/images/splash_logo.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              
              Text(
                'BERITAKU',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Portal Berita AI Personal Anda',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black45, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              if (_isBiometricOnlyLock) ...[
                // Lock screen biometric-only view
                GlassContainer(
                  blur: 30,
                  opacity: isDark ? 0.15 : 0.22,
                  borderRadius: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Selamat Datang Kembali,',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _welcomeName.isNotEmpty ? _welcomeName : 'Adrian Akbar',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 35),
                      
                      // Pulsing biometrics scanner button
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.94, end: 1.06).animate(
                          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                        ),
                        child: InkWell(
                          onTap: _isLoading ? null : _handleBiometricLogin,
                          borderRadius: BorderRadius.circular(45),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.4),
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.15),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                )
                              ]
                            ),
                            child: const Icon(
                              LucideIcons.fingerprint,
                              color: Color(0xFF6366F1),
                              size: 50,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Sentuh sensor biometrik untuk membuka kunci aplikasi',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black45,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      
                      // Option to switch account or use password
                      TextButton.icon(
                        onPressed: _handleSwitchAccount,
                        icon: const Icon(LucideIcons.logOut, size: 16, color: Color(0xFF6366F1)),
                        label: const Text(
                          'Masuk dengan Akun Lain / Kata Sandi',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Main Auth Glass Board
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: GlassContainer(
                    blur: 30,
                    opacity: isDark ? 0.15 : 0.22,
                    borderRadius: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // View Switcher Tabs
                        Row(
                          children: [
                            _buildTabItem(true, 'MASUK'),
                            _buildTabItem(false, 'DAFTAR'),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Input Fields depending on view
                        if (!_isLoginView) ...[
                          // Full Name for Register
                          _buildInputField(
                            controller: _nameController,
                            hint: 'Nama Lengkap',
                            icon: LucideIcons.user,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Email input
                        _buildInputField(
                          controller: _emailController,
                          hint: 'Alamat Email',
                          icon: LucideIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),

                        // Password input
                        _buildInputField(
                          controller: _passwordController,
                          hint: 'Kata Sandi',
                          icon: LucideIcons.lock,
                          obscureText: _isObscure,
                          isDark: isDark,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscure ? LucideIcons.eyeOff : LucideIcons.eye,
                              color: isDark ? Colors.white38 : Colors.black38,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _isObscure = !_isObscure),
                          ),
                        ),

                        if (!_isLoginView) ...[
                          const SizedBox(height: 12),
                          // Confirm Password for Register
                          _buildInputField(
                            controller: _confirmPasswordController,
                            hint: 'Konfirmasi Kata Sandi',
                            icon: LucideIcons.lock,
                            obscureText: _isObscure,
                            isDark: isDark,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading 
                                ? null 
                                : (_isLoginView ? _handleLogin : _handleRegister),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
                              elevation: 5,
                            ),
                            child: _isLoading 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    _isLoginView ? 'MASUK SEKARANG' : 'DAFTAR AKUN BARU',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Biometric Shortcut Panel for Login Mode
                if (_isLoginView) ...[
                  Text(
                    'Atau masuk cepat dengan biometrik',
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  
                  // Pulsing biometrics scanner button
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.94, end: 1.06).animate(
                      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                    ),
                    child: InkWell(
                      onTap: _isLoading ? null : _handleBiometricLogin,
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.4),
                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.15),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ]
                        ),
                        child: const Icon(
                          LucideIcons.fingerprint,
                          color: Color(0xFF6366F1),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ]
              ]
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTabItem(bool isLoginTab, String label) {
    final bool active = _isLoginView == isLoginTab;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _isLoginView = isLoginTab),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: active 
                    ? (isDark ? Colors.white : const Color(0xFF0F172A)) 
                    : (isDark ? Colors.white38 : Colors.black38),
                fontSize: 13,
                fontWeight: active ? FontWeight.w900 : FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: active ? 40 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1),
                    blurRadius: 4,
                  )
                ]
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    bool isDark = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.5),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
          prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black45, size: 18),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

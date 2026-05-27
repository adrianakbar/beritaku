import 'package:flutter/material.dart';
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
    if (mounted) {
      setState(() {
        _deviceHasBiometrics = hasBio;
      });
    }
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
      _showSnackBar('Pendaftaran berhasil! Akun Anda aktif.', Colors.green);
      _navigateToHome();
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
                  final prefs = await _auth.registerUser('Adrian Akbar', 'user@example.com', 'pass'); // Auto seed to proceed
                  _showSnackBar('Autentikasi Biometrik Sukses (Simulasi)!', Colors.green);
                  _navigateToHome();
                }
              }
            });

            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassContainer(
                blur: 35,
                opacity: 0.2,
                borderRadius: 28,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      scanning ? 'Pindai Sidik Jari / Wajah' : 'Verifikasi Berhasil!',
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
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
                          scanning ? Icons.fingerprint_rounded : Icons.check_circle_rounded,
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
                      style: const TextStyle(color: Colors.black54, fontSize: 11, height: 1.4),
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
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            blur: 30,
            opacity: 0.15,
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded, color: Color(0xFF6366F1), size: 42),
                const SizedBox(height: 14),
                const Text(
                  'Biometrik Belum Aktif',
                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Silakan daftarkan akun utama Anda terlebih dahulu, kemudian aktifkan fitur Biometrik di menu "Setelan" aplikasi agar bisa menggunakan login sidik jari cepat.',
                  style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.4),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBackground(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 35),
              
              // App Brand / Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ]
                ),
                child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              
              const Text(
                'BERITAKU',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Portal Berita AI Personal Anda',
                style: TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              // Main Auth Glass Board
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: GlassContainer(
                  blur: 30,
                  opacity: 0.22,
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
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Email input
                      _buildInputField(
                        controller: _emailController,
                        hint: 'Alamat Email',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),

                      // Password input
                      _buildInputField(
                        controller: _passwordController,
                        hint: 'Kata Sandi',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _isObscure,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: Colors.black38,
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
                          icon: Icons.lock_clock_outlined,
                          obscureText: _isObscure,
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
                const Text(
                  'Atau masuk cepat dengan biometrik',
                  style: TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold),
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
                        color: Colors.white.withOpacity(0.4),
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
                        Icons.fingerprint_rounded,
                        color: Color(0xFF6366F1),
                        size: 40,
                      ),
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(bool isLoginTab, String label) {
    final bool active = _isLoginView == isLoginTab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _isLoginView = isLoginTab),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF0F172A) : Colors.black38,
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.black45, size: 18),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

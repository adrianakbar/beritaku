import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../main.dart';
import '../services/tts_service.dart';
import '../services/auth_service.dart';

import '../services/notification_service.dart';
import '../models/feed_source.dart';
import '../models/news_article.dart';
import '../widgets/glass_container.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => _isDark ? Colors.white : const Color(0xFF0F172B);
  Color get _subtitleColor => _isDark ? Colors.white70 : const Color(0xFF4B5563);
  Color get _captionColor => _isDark ? Colors.white30 : const Color(0xFF9CA3AF);

  final StorageService _storage = StorageService();
  final GeminiService _gemini = GeminiService();
  final TtsService _tts = TtsService();
  final AuthService _auth = AuthService();
  final NotificationService _notifications = NotificationService();

  // Controllers
  final TextEditingController _apiKeyController = TextEditingController();
  
  // Custom Feed Controllers
  final TextEditingController _feedNameController = TextEditingController();
  final TextEditingController _feedUrlController = TextEditingController();
  String _selectedFeedType = 'rss';
  String _selectedCategory = 'Umum';

  // UI State
  bool _obfuscateApiKey = true;
  bool _testingGemini = false;
  
  List<FeedSource> _sources = [];

  // New Features State
  bool _biometricEnabled = false;
  bool _deviceSupportsBiometrics = false;
  bool _reminderEnabled = false;
  int _reminderHour = 8;
  int _reminderMinute = 0;
  String _userName = 'Adrian Akbar';


  String _selectedThemeMode = 'system';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _storage.init();
    _apiKeyController.text = _storage.getGeminiApiKey();
    
    _sources = _storage.getFeedSources();

    // Load auth & reminder preferences
    _biometricEnabled = await _auth.isBiometricEnabled();
    _deviceSupportsBiometrics = await _auth.isBiometricSupported();
    _userName = await _auth.getUserName();

    _reminderEnabled = await _notifications.isReminderEnabled();
    _reminderHour = await _notifications.getReminderHour();
    _reminderMinute = await _notifications.getReminderMinute();



    // Load theme setting
    _selectedThemeMode = _storage.getThemeMode();

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _feedNameController.dispose();
    _feedUrlController.dispose();
    super.dispose();
  }

  // Gemini Action Methods
  Future<void> _testGeminiApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _showSnackBar('Silakan masukkan API Key terlebih dahulu.', Colors.amber);
      return;
    }

    setState(() => _testingGemini = true);
    final success = await _gemini.testConnection(key);
    setState(() => _testingGemini = false);

    if (success) {
      await _storage.setGeminiApiKey(key);
      _showSnackBar('Koneksi Gemini AI Berhasil! Kunci disimpan.', Colors.green);
    } else {
      _showSnackBar('Koneksi Gagal. Periksa kembali API Key Anda.', Colors.red);
    }
  }



  // Feed Actions
  Future<void> _addCustomFeed() async {
    final name = _feedNameController.text.trim();
    final url = _feedUrlController.text.trim();

    if (name.isEmpty || url.isEmpty) {
      _showSnackBar('Nama dan URL feed tidak boleh kosong.', Colors.amber);
      return;
    }

    final newSource = FeedSource(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      url: url,
      type: _selectedFeedType,
      isEnabled: true,
      category: _selectedCategory,
    );

    await _storage.addFeedSource(newSource);
    
    _feedNameController.clear();
    _feedUrlController.clear();
    await _loadSettings();
    Navigator.of(context).pop();
    _showSnackBar('Sumber berita "$name" ditambahkan!', Colors.green);
  }

  Future<void> _toggleFeedSource(FeedSource source, bool val) async {
    await _storage.updateFeedSource(source.copyWith(isEnabled: val));
    await _loadSettings();
  }

  Future<void> _deleteFeedSource(String id, String name) async {
    await _storage.deleteFeedSource(id);
    await _loadSettings();
    _showSnackBar('Sumber "$name" dihapus.', Colors.redAccent);
  }

  void _updateTheme(String newTheme) {
    setState(() {
      _selectedThemeMode = newTheme;
    });
    BeritakuApp.of(context)?.changeTheme(newTheme);
  }

  void _testSpeech() {
    _tts.speakArticle(
      NewsArticle(
        id: 'dummy-tts-settings',
        title: 'Pengaturan Suara Siap',
        description: 'Sampel suara pembaca berita.',
        content: 'Halo $_userName! Fitur audio podcast berita personal Anda telah dikonfigurasi dengan sukses di tema baru Light Glass ini.',
        url: '',
        sourceName: 'Asisten Beritaku',
        publishedAt: DateTime.now(),
      )
    );
    _showSnackBar('Memutar sampel suara asisten...', Colors.teal);
  }

  // --- NEW FEATURES ACTIONS ---
  
  // Toggle Biometric Lock status
  Future<void> _toggleBiometrics(bool val) async {
    if (val && !_deviceSupportsBiometrics) {
      _showSnackBar('Perangkat Anda tidak mendukung sensor biometrik sidik jari / wajah.', Colors.amber);
      return;
    }

    await _auth.setBiometricEnabled(val);
    setState(() {
      _biometricEnabled = val;
    });
    _showSnackBar(val ? 'Keamanan Biometrik Aktif!' : 'Keamanan Biometrik Dinonaktifkan.', Colors.indigo);
  }

  // Toggle Daily Reminder Alarm
  Future<void> _toggleDailyReminder(bool val) async {
    await _notifications.setReminderEnabled(val);
    setState(() {
      _reminderEnabled = val;
    });
    _showSnackBar(val ? 'Pengingat Harian Diaktifkan!' : 'Pengingat Harian Dinonaktifkan.', Colors.indigo);
  }

  // Select custom reminder hour & minute using Time Picker
  Future<void> _selectReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF6366F1), // Header text / active color
              onPrimary: Colors.white,
              onSurface: _textColor, // Body text
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await _notifications.setReminderHour(picked.hour);
      await _notifications.setReminderMinute(picked.minute);
      await _loadSettings();
      _showSnackBar('Pengingat harian dijadwalkan pukul ${picked.format(context)}', Colors.green);
    }
  }

  // Trigger test notification
  Future<void> _triggerTestNotification() async {
    await _notifications.showTestNotification();
    _showSnackBar('Memicu notifikasi penguji ke sistem bar...', Colors.teal);
  }

  // Log out action
  Future<void> _handleLogout() async {
    await _auth.logoutUser();
    _showSnackBar('Sesi masuk Anda telah diakhiri.', Colors.blueGrey);
    
    // Jump back to Login Screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: color.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.only(bottom: 100, left: 20, right: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedReminderTime = '${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo,',
                        style: TextStyle(
                          fontSize: 14,
                          color: _subtitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '$_userName 👋',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _textColor,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Sesuaikan proteksi keamanan dan setelan Anda',
                        style: TextStyle(
                          fontSize: 12,
                          color: _subtitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // NEW SECTION: Security & Reminders (Biometrics & Daily Notification)
          _buildSectionHeader('Keamanan & Pengingat Harian', LucideIcons.shield, Colors.indigoAccent),
          GlassContainer(
            opacity: 0.22,
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Biometrics Switch
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                      child: Icon(LucideIcons.fingerprint, color: const Color(0xFF6366F1), size: 18),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kunci Biometrik Cepat',
                            style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            _deviceSupportsBiometrics 
                                ? 'Autentikasi sidik jari/wajah saat masuk'
                                : 'Hardware tidak didukung perangkat',
                            style: TextStyle(color: _captionColor, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _biometricEnabled,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: _toggleBiometrics,
                    )
                  ],
                ),
                
                Divider(color: _textColor.withOpacity(0.06), height: 24),
                
                // 2. Daily Reminder Notifications Switch
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.pinkAccent.withOpacity(0.1),
                      child: Icon(LucideIcons.bell, color: Colors.pinkAccent, size: 18),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengingat Membaca Harian',
                            style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Notifikasi alarm terjadwal membaca berita',
                            style: TextStyle(color: _captionColor, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _reminderEnabled,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: _toggleDailyReminder,
                    )
                  ],
                ),
                
                // Reminder Details (if enabled, show Time Picker)
                if (_reminderEnabled) ...[
                  SizedBox(height: 14),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _textColor.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _textColor.withOpacity(0.04)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.alarmClock, color: _captionColor, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Waktu Alarm: $formattedReminderTime',
                            style: TextStyle(color: _textColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        
                        // Change time button
                        TextButton(
                          onPressed: _selectReminderTime,
                          child: Text(
                            'Ubah Waktu',
                            style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: _triggerTestNotification,
                      icon: Icon(LucideIcons.bellOff, size: 14, color: Colors.pinkAccent),
                      label: Text('Kirim Notifikasi Uji Coba', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 10.5)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.pinkAccent.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),
          SizedBox(height: 24),

          // 1. Gemini Config Section
          _buildSectionHeader('Fitur AI Ringkasan (Gemini)', LucideIcons.sparkles, Colors.purple),
          GlassContainer(
            opacity: 0.22,
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google AI Studio API Key',
                  style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obfuscateApiKey,
                  style: TextStyle(color: _textColor, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Masukkan AI Studio API Key...',
                    hintStyle: TextStyle(color: _captionColor, fontSize: 13),
                    filled: true,
                    fillColor: _textColor.withOpacity(0.04),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obfuscateApiKey ? LucideIcons.eyeOff : LucideIcons.eye,
                        color: _captionColor,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obfuscateApiKey = !_obfuscateApiKey),
                    ),
                  ),
                  onChanged: (val) => _storage.setGeminiApiKey(val.trim()),
                ),
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _testingGemini ? null : _testGeminiApiKey,
                    icon: _testingGemini 
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(LucideIcons.zap, size: 18),
                    label: Text(_testingGemini ? 'Mencoba...' : 'Test & Simpan Koneksi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shadowColor: const Color(0xFF6366F1).withOpacity(0.3),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Kunci API disimpan secara lokal di HP Anda dan digunakan secara gratis langsung ke Google AI Studio.',
                  style: TextStyle(color: _captionColor, fontSize: 10, height: 1.4),
                )
              ],
            ),
          ),

          SizedBox(height: 24),

          // 3. Feed Manager
          _buildSectionHeader('Daftar Umpan Berita (Feed Manager)', LucideIcons.rss, Colors.green),
          GlassContainer(
            opacity: 0.22,
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sumber Aliran Berita',
                      style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _showAddFeedDialog,
                      icon: Icon(LucideIcons.plus, size: 16, color: const Color(0xFF6366F1)),
                      label: Text('Tambah', style: TextStyle(color: const Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                SizedBox(height: 8),
                _sources.isEmpty
                    ? Text(
                        'Daftar umpan kosong.',
                        style: TextStyle(color: _captionColor, fontSize: 12),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _sources.length,
                        separatorBuilder: (_, __) => Divider(color: _textColor.withOpacity(0.05)),
                        itemBuilder: (context, index) {
                          final src = _sources[index];
                          IconData typeIcon = LucideIcons.rss;
                          if (src.type == 'reddit') typeIcon = LucideIcons.messageSquare;
                          if (src.type == 'hackernews') typeIcon = LucideIcons.terminal;

                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _textColor.withOpacity(0.04),
                                  child: Icon(typeIcon, color: const Color(0xFF6366F1), size: 16),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        src.name,
                                        style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        src.type == 'reddit' ? 'r/${src.url}' : src.url,
                                        style: TextStyle(color: _captionColor, fontSize: 10),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: src.isEnabled,
                                  activeColor: const Color(0xFF6366F1),
                                  onChanged: (val) => _toggleFeedSource(src, val),
                                ),
                                IconButton(
                                  icon: Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteFeedSource(src.id, src.name),
                                )
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // 4. Text to Speech
          _buildSectionHeader('Text-to-Speech (Suara Podcast)', LucideIcons.volume2, Colors.teal),
          GlassContainer(
            opacity: 0.22,
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kecepatan Membaca (Speech Rate)',
                  style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Icon(LucideIcons.activity, color: _captionColor, size: 18),
                    Expanded(
                      child: Slider(
                        value: _storage.getTtsSpeed(),
                        min: 0.3,
                        max: 0.8,
                        divisions: 10,
                        activeColor: const Color(0xFF6366F1),
                        inactiveColor: _textColor.withOpacity(0.05),
                        onChanged: (val) async {
                          await _tts.setSpeed(val);
                          setState(() {});
                        },
                      ),
                    ),
                    Icon(LucideIcons.zap, color: _captionColor, size: 18),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'Pitch Suara (Nada Suara)',
                  style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Icon(LucideIcons.chevronDown, color: _captionColor, size: 18),
                    Expanded(
                      child: Slider(
                        value: _storage.getTtsPitch(),
                        min: 0.7,
                        max: 1.4,
                        divisions: 7,
                        activeColor: const Color(0xFF6366F1),
                        inactiveColor: _textColor.withOpacity(0.05),
                        onChanged: (val) async {
                          await _tts.setPitch(val);
                          setState(() {});
                        },
                      ),
                    ),
                    Icon(LucideIcons.chevronUp, color: _captionColor, size: 18),
                  ],
                ),
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _testSpeech,
                    icon: const Icon(LucideIcons.headphones, size: 18, color: Color(0xFF6366F1)),
                    label: Text('Uji Coba Suara Asisten', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // 5. Tema Pilihan (Dark, Light, System)
          _buildSectionHeader('Tampilan & Tema', LucideIcons.palette, Colors.indigo),
          GlassContainer(
            opacity: 0.22,
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tema Aplikasi',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sesuaikan tampilan visual portal berita sesuai kenyamanan mata Anda.',
                  style: TextStyle(color: _captionColor, fontSize: 10),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildThemeChoiceCard('system', LucideIcons.sliders, 'Sistem'),
                    const SizedBox(width: 8),
                    _buildThemeChoiceCard('light', LucideIcons.sun, 'Terang'),
                    const SizedBox(width: 8),
                    _buildThemeChoiceCard('dark', LucideIcons.moon, 'Gelap'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 6. Logout & Profil Card Option
          _buildSectionHeader('Profil & Autentikasi', LucideIcons.user, Colors.redAccent),
          GlassContainer(
            opacity: 0.22,
            borderRadius: 24,
            glassColor: Colors.redAccent.withOpacity(0.02),
            customBorder: Border.all(color: Colors.redAccent.withOpacity(0.25), width: 1.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kelola Informasi Profil',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nama Anda saat ini: $_userName',
                  style: TextStyle(color: _subtitleColor, fontSize: 10),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showEditNameDialog,
                        icon: const Icon(LucideIcons.edit3, size: 14, color: Color(0xFF6366F1)),
                        label: Text(
                          'Ubah Nama',
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.35)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(LucideIcons.logOut, size: 14, color: Colors.white),
                        label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildThemeChoiceCard(String mode, IconData icon, String label) {
    final bool isSelected = _selectedThemeMode == mode;
    
    return Expanded(
      child: InkWell(
        onTap: () => _updateTheme(mode),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1)
                : (_isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : (_isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (_isDark ? Colors.white70 : _textColor),
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (_isDark ? Colors.white70 : _textColor),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(left: 4.0, bottom: 10.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _captionColor, fontSize: 11),
      filled: true,
      fillColor: _textColor.withOpacity(0.04),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _showAddFeedDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            blur: 35,
            opacity: 0.35,
            borderRadius: 24,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tambah Umpan Berita',
                      style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _feedNameController,
                      style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration('Nama Sumber Berita (misal: Detik News)'),
                    ),
                    SizedBox(height: 10),
                    
                    Text('Tipe Sumber:', style: TextStyle(color: _captionColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        _buildTypeChip(setDialogState, 'rss', 'RSS XML'),
                        SizedBox(width: 8),
                        _buildTypeChip(setDialogState, 'reddit', 'Reddit Sub'),
                        SizedBox(width: 8),
                        _buildTypeChip(setDialogState, 'hackernews', 'HN API'),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _feedUrlController,
                      style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration(
                        _selectedFeedType == 'rss' 
                            ? 'URL RSS Feed lengkap...'
                            : _selectedFeedType == 'reddit' 
                                ? 'Nama Subreddit (misal: androiddev)...' 
                                : 'Endpoint HN API default...'
                      ),
                    ),
                    SizedBox(height: 14),
                    
                    Text('Kategori Tab:', style: TextStyle(color: _captionColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      dropdownColor: _isDark ? const Color(0xFF1E293B) : const Color(0xFFFAFBFD),
                      style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration('Kategori'),
                      items: ['Nasional', 'Teknologi', 'Kreatif', 'Umum'].map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => _selectedCategory = val);
                        }
                      },
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Batal', style: TextStyle(color: _captionColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _addCustomFeed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text('Tambah Sumber', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeChip(StateSetter setDialogState, String type, String label) {
    final bool isSelected = _selectedFeedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setDialogState(() => _selectedFeedType = type);
          if (type == 'hackernews') {
            _feedUrlController.text = 'https://hacker-news.firebaseio.com/v0/topstories.json';
            _feedNameController.text = 'Hacker News';
          } else {
            _feedUrlController.clear();
            _feedNameController.clear();
          }
          setState(() {});
        }
      },
      selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
      backgroundColor: _textColor.withOpacity(0.04),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF6366F1) : _captionColor,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF6366F1).withOpacity(0.5) : _textColor.withOpacity(0.05),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }



  void _showEditNameDialog() {
    final TextEditingController nameEditController = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F6FA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(LucideIcons.user, color: const Color(0xFF6366F1), size: 22),
              SizedBox(width: 8),
              Text('Ubah Nama Lengkap', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan nama lengkap baru Anda:',
                style: TextStyle(color: _subtitleColor, fontSize: 12),
              ),
              SizedBox(height: 12),
              TextField(
                controller: nameEditController,
                style: TextStyle(color: _textColor, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _textColor.withOpacity(0.04),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(LucideIcons.user, color: _captionColor, size: 18),
                ),
                autofocus: true,
              ),
            ],
          ),
          actionsPadding: EdgeInsets.only(bottom: 16, right: 16, left: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal', style: TextStyle(color: _subtitleColor, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameEditController.text.trim();
                if (newName.isNotEmpty) {
                  await _auth.updateUserName(newName);
                  if (context.mounted) {
                    setState(() {
                      _userName = newName;
                    });
                    Navigator.pop(context);
                    _showSnackBar('Nama lengkap berhasil diubah!', Colors.green);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

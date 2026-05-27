import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_article.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../services/tts_service.dart';
import '../widgets/liquid_background.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_widgets.dart';

class ArticleDetailScreen extends StatefulWidget {
  final NewsArticle article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final StorageService _storage = StorageService();
  final GeminiService _gemini = GeminiService();
  final TtsService _tts = TtsService();

  late NewsArticle _article;
  bool _isBookmarked = false;
  bool _isGeneratingAi = false;
  double _fontSize = 14.0;
  String _titleFont = 'Playfair Display';
  String _bodyFont = 'Lora';

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _checkBookmarkStatus();
    _tts.addListener(_onTtsChange);
  }

  void _onTtsChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tts.removeListener(_onTtsChange);
    super.dispose();
  }

  Future<void> _checkBookmarkStatus() async {
    await _storage.init();
    final saved = await _storage.getSavedArticle(_article.id);
    _titleFont = _storage.getSelectedTitleFont();
    _bodyFont = _storage.getSelectedBodyFont();
    
    if (mounted) {
      setState(() {
        if (saved != null) {
          _isBookmarked = true;
          _article = saved;
        }
      });
    }
  }

  Future<void> _generateAiSummary() async {
    setState(() => _isGeneratingAi = true);
    try {
      final analyzed = await _gemini.analyzeArticle(_article);
      setState(() {
        _article = analyzed;
        _isGeneratingAi = false;
      });
      _showToast('Ringkasan AI berhasil dibuat!');
    } catch (e) {
      setState(() => _isGeneratingAi = false);
      _showErrorDialog(e.toString().replaceAll('Exception:', ''));
    }
  }

  Future<void> _toggleOfflineSave() async {
    if (_isBookmarked) {
      await _storage.removeArticleOffline(_article.id);
      setState(() => _isBookmarked = false);
      _showToast('Dihapus dari penyimpanan luring.');
    } else {
      await _storage.saveArticleOffline(_article);
      setState(() => _isBookmarked = true);
      _showToast('Berhasil disimpan offline!');
    }
  }

  Future<void> _launchUrl() async {
    final uri = Uri.parse(_article.url);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Success
    } else {
      _showToast('Gagal membuka tautan.');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 120, left: 30, right: 30),
      ),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            blur: 30,
            opacity: 0.2,
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 42),
                const SizedBox(height: 14),
                const Text(
                  'Gagal Memproses AI',
                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  msg,
                  style: const TextStyle(color: Colors.black87, fontSize: 12, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final hasAiSummary = _article.summaryBullets.isNotEmpty;
    final String formattedDate = DateFormat('dd MMMM yyyy, HH:mm').format(_article.publishedAt);
    final isTtsActiveForThis = _tts.isPlaying && _tts.currentArticle?.id == _article.id;

    return LiquidBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.format_size_rounded, color: Color(0xFF0F172A)),
              onPressed: () {
                setState(() {
                  if (_fontSize == 14.0) _fontSize = 17.0;
                  else if (_fontSize == 17.0) _fontSize = 20.0;
                  else _fontSize = 14.0;
                });
              },
            ),
            IconButton(
              icon: Icon(
                _isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                color: _isBookmarked ? const Color(0xFF6366F1) : const Color(0xFF0F172A),
              ),
              onPressed: _toggleOfflineSave,
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source & Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                        ),
                        child: Text(
                          _article.sourceName.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(color: Colors.black45, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    _article.title,
                    style: GoogleFonts.getFont(
                      _titleFont,
                      color: const Color(0xFF0F172A),
                      fontSize: 22, // Slightly larger for dynamic editorial presence
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gemini AI Insights Box
                  _buildGeminiAiPanel(hasAiSummary),
                  const SizedBox(height: 20),

                  // Image
                  if (_article.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.black.withOpacity(0.02),
                        child: Image.network(
                          _article.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Article Content
                  Text(
                    _article.content,
                    style: GoogleFonts.getFont(
                      _bodyFont,
                      color: const Color(0xFF1E293B), // Premium high contrast dark slate reading color
                      fontSize: _fontSize,
                      height: 1.75, // Generous line spacing for comfortable reading
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Footer Actions
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _launchUrl,
                      icon: const Icon(Icons.open_in_browser_rounded, size: 18, color: Color(0xFF4F46E5)),
                      label: const Text('Buka Tautan Asli Berita', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Floating TTS Controller
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: _buildTtsAudioControlPanel(isTtsActiveForThis),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiAiPanel(bool hasAiSummary) {
    if (_isGeneratingAi) {
      return GlassContainer(
        opacity: 0.22,
        borderRadius: 24,
        customBorder: Border.all(color: const Color(0xFF6366F1).withOpacity(0.35)),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI Sedang Membaca & Meringkas...',
                  style: TextStyle(color: const Color(0xFF0F172A).withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.bold),
                )
              ],
            ),
            const SizedBox(height: 14),
            const GlassShimmer(width: double.infinity, height: 12, borderRadius: 6),
            const SizedBox(height: 8),
            const GlassShimmer(width: double.infinity, height: 12, borderRadius: 6),
            const SizedBox(height: 8),
            const GlassShimmer(width: 220, height: 12, borderRadius: 6),
          ],
        ),
      );
    }

    if (!hasAiSummary) {
      return InkWell(
        onTap: _generateAiSummary,
        borderRadius: BorderRadius.circular(24),
        child: GlassContainer(
          opacity: 0.16,
          borderRadius: 24,
          glassColor: const Color(0xFF6366F1).withOpacity(0.04),
          customBorder: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 1.0),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5), size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Butuh Ringkasan Otomatis?',
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ketuk untuk membaca 3 poin inti & sentimen berita menggunakan Gemini AI.',
                      style: TextStyle(color: Colors.black54, fontSize: 10, height: 1.3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black38, size: 14),
            ],
          ),
        ),
      );
    }

    return GlassContainer(
      opacity: 0.22,
      borderRadius: 24,
      glassColor: const Color(0xFF6366F1).withOpacity(0.02),
      customBorder: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'GEMINI AI INSIGHTS',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              SentimentBadge(category: _article.sentimentCategory),
            ],
          ),
          
          if (_article.sentimentDescription != null) ...[
            const SizedBox(height: 8),
            Text(
              _article.sentimentDescription!,
              style: const TextStyle(color: Colors.black87, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 12),
          Divider(color: Colors.black.withOpacity(0.06)),
          const SizedBox(height: 6),

          Column(
            children: _article.summaryBullets.map((bullet) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.blur_on_rounded, color: Color(0xFF4F46E5), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bullet,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTtsAudioControlPanel(bool isActiveSpeaker) {
    final double curSpeed = _storage.getTtsSpeed();

    return GlassContainer(
      blur: 35,
      opacity: 0.35,
      borderOpacity: 0.45,
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: (isActiveSpeaker ? const Color(0xFF6366F1) : Colors.black).withOpacity(0.04),
            child: Icon(
              isActiveSpeaker ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
              color: isActiveSpeaker ? const Color(0xFF4F46E5) : Colors.black54,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PODCAST RADIO BERITA',
                  style: TextStyle(color: Color(0xFF4F46E5), fontSize: 9, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  isActiveSpeaker ? 'Sedang dibacakan...' : 'Dengarkan Berita Ini',
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Kecepatan Suara: ${curSpeed.toStringAsFixed(2)}x',
                  style: const TextStyle(color: Colors.black45, fontSize: 8.5),
                )
              ],
            ),
          ),

          IconButton(
            icon: Icon(
              isActiveSpeaker && _tts.isPlaying 
                  ? Icons.pause_circle_rounded 
                  : Icons.play_circle_rounded,
              color: const Color(0xFF4F46E5),
              size: 38,
            ),
            onPressed: () {
              if (isActiveSpeaker && _tts.isPlaying) {
                _tts.pause();
              } else if (isActiveSpeaker && _tts.isPaused) {
                _tts.resume();
              } else {
                _tts.speakArticle(_article);
              }
            },
          ),

          if (isActiveSpeaker)
            IconButton(
              icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 30),
              onPressed: () {
                _tts.stop();
              },
            ),
        ],
      ),
    );
  }
}

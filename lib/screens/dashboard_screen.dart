import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../services/rss_service.dart';
import '../services/tts_service.dart';
import '../services/auth_service.dart';
import '../models/news_article.dart';
import '../models/feed_source.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_widgets.dart';
import 'article_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final StorageService _storage = StorageService();
  final RssService _rss = RssService();
  final TtsService _tts = TtsService();
  final AuthService _auth = AuthService();

  List<NewsArticle> _articles = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategoryTab = 'Semua';
  String _userName = 'Adrian';
  
  final List<String> _categories = ['Semua', 'Nasional', 'Teknologi', 'Umum'];

  @override
  void initState() {
    super.initState();
    _initAndFetch();
    _tts.addListener(_onTtsStateChange);
  }

  void _onTtsStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tts.removeListener(_onTtsStateChange);
    super.dispose();
  }

  Future<void> _initAndFetch() async {
    await _storage.init();
    _userName = await _auth.getUserName();
    await _fetchNews();
  }

  Future<void> _fetchNews() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final fetched = await _rss.fetchArticles();
      if (mounted) {
        setState(() {
          _articles = fetched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi, $_userName! 🌅';
    if (hour < 15) return 'Selamat Siang, $_userName! ☀️';
    if (hour < 18) return 'Selamat Sore, $_userName! 🌇';
    return 'Selamat Malam, $_userName! 🌌';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  List<NewsArticle> _getFilteredArticles() {
    List<NewsArticle> filtered = _articles;

    if (_selectedCategoryTab != 'Semua') {
      final List<FeedSource> enabledSources = _storage.getFeedSources();
      filtered = filtered.where((art) {
        try {
          final src = enabledSources.firstWhere(
            (element) => element.name == art.sourceName || art.sourceName.contains(element.name)
          );
          return src.category == _selectedCategoryTab;
        } catch (_) {
          if (art.sourceName.contains('Reddit') || art.sourceName.contains('Hacker News')) {
            return _selectedCategoryTab == 'Teknologi';
          }
          return _selectedCategoryTab == 'Umum';
        }
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((element) {
        return element.title.toLowerCase().contains(query) ||
            element.description.toLowerCase().contains(query) ||
            element.sourceName.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _toggleBookmark(NewsArticle article) async {
    final saved = await _storage.getSavedArticle(article.id);
    if (saved != null) {
      await _storage.removeArticleOffline(article.id);
      _showToast('Dihapus dari simpanan');
    } else {
      await _storage.saveArticleOffline(article);
      _showToast('Disimpan untuk nanti luring');
    }
    
    setState(() {
      _articles = _articles.map((e) {
        if (e.id == article.id) {
          return e.copyWith(
            isBookmarked: saved == null,
            isOfflineSaved: saved == null,
          );
        }
        return e;
      }).toList();
    });
  }

  void _startContinuousPodcastMode() {
    final list = _getFilteredArticles();
    if (list.isEmpty) {
      _showToast('Umpan kosong. Tidak ada berita.');
      return;
    }

    _showToast('Memulai Mode Podcast Berita...');
    
    int currentIndex = 0;
    
    void playNext() {
      if (currentIndex < list.length) {
        final article = list[currentIndex];
        _tts.speakArticle(article);
        currentIndex++;
      } else {
        _tts.stop();
        _showToast('Semua berita selesai dibacakan.');
      }
    }

    _tts.setCompletionCallback(playNext);
    playNext();
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 100, left: 40, right: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredArticles();
    final bool isGeminiConfigured = _storage.getGeminiApiKey().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A), // Dark slate black
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Umpan Ringkasan AI Terintegrasi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54, // Soft grey slate
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              IconButton(
                icon: Icon(
                  _tts.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: const Color(0xFF6366F1),
                  size: 38,
                ),
                onPressed: () {
                  if (_tts.isPlaying) {
                    _tts.stop();
                    _tts.removeCompletionCallback();
                    _showToast('Mode Podcast dihentikan.');
                  } else {
                    _startContinuousPodcastMode();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gemini warning banner
          if (!isGeminiConfigured)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: InkWell(
                onTap: () {
                  _showToast('Silakan buka tab "Setelan" untuk mengisi API Key Gemini.');
                },
                child: GlassContainer(
                  glassColor: Colors.amber.withOpacity(0.08),
                  customBorder: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.0),
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Ringkasan AI Belum Aktif',
                              style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Masukkan API Key Gemini di tab Setelan untuk menyalakan Ringkasan AI.',
                              style: TextStyle(color: Colors.black54, fontSize: 9, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber, size: 12),
                    ],
                  ),
                ),
              ),
            ),

          // Search Bar
          GlassContainer(
            borderRadius: 16.0,
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 0.0),
            opacity: 0.16, // Darker milky opacity for input contrast
            child: TextField(
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Cari berita hari ini...',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                icon: Icon(Icons.search_rounded, color: Colors.black45, size: 20),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Categories tabs
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final bool isSelected = _selectedCategoryTab == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedCategoryTab = cat;
                        });
                      }
                    },
                    selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
                    backgroundColor: Colors.white.withOpacity(0.4),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF6366F1) : Colors.black54,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF6366F1).withOpacity(0.5) : Colors.black.withOpacity(0.04),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Podcast bar
          if (_tts.isPlaying)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.radio_rounded, color: Color(0xFF6366F1), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SEDANG BERPUTAR: "${_tts.currentArticle?.title ?? ''}"',
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 9, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 10,
                    child: _VisualizerAnimation(),
                  )
                ],
              ),
            ),

          // Main list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchNews,
              color: const Color(0xFF6366F1),
              backgroundColor: Colors.white,
              child: _isLoading
                  ? _buildShimmerLoading()
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.only(bottom: 40),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final article = filtered[index];
                            return _buildArticleCard(article);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (_, __) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: GlassContainer(
            borderRadius: 20,
            opacity: 0.15,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GlassShimmer(width: 120, height: 12, borderRadius: 6),
                      const SizedBox(height: 10),
                      const GlassShimmer(width: double.infinity, height: 16, borderRadius: 8),
                      const SizedBox(height: 6),
                      const GlassShimmer(width: 200, height: 16, borderRadius: 8),
                      const SizedBox(height: 14),
                      Row(
                        children: const [
                          GlassShimmer(width: 60, height: 10, borderRadius: 5),
                          SizedBox(width: 10),
                          GlassShimmer(width: 80, height: 10, borderRadius: 5),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const GlassShimmer(width: 90, height: 90, borderRadius: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feed_outlined, size: 60, color: Colors.black26),
            const SizedBox(height: 14),
            const Text(
              'Tidak ada berita ditemukan',
              style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Umpan kustom kosong. Tarik ke bawah untuk refresh atau matikan filter kata kunci kustom Anda di Setelan.',
                style: TextStyle(color: Colors.black45, fontSize: 11, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(NewsArticle article) {
    final bool bookmarked = article.isBookmarked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailScreen(article: article),
            ),
          ).then((value) {
            _fetchNews();
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: GlassContainer(
          borderRadius: 20,
          opacity: 0.2, // milky glass opacity card
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Source
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            article.sourceName.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF4F46E5),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (article.sentimentCategory != null)
                          SentimentBadge(category: article.sentimentCategory, compact: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Title
                    Text(
                      article.title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    
                    // Description
                    Text(
                      article.description,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    
                    // Date & Actions
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: Colors.black38, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(article.publishedAt),
                          style: const TextStyle(color: Colors.black38, fontSize: 10),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _toggleBookmark(article),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Icon(
                              bookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
                              color: bookmarked ? const Color(0xFF6366F1) : Colors.black38,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              if (article.imageUrl != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 86,
                    height: 86,
                    color: Colors.black.withOpacity(0.02),
                    child: Image.network(
                      article.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.black12, size: 24),
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
}

class _VisualizerAnimation extends StatefulWidget {
  const _VisualizerAnimation();

  @override
  State<_VisualizerAnimation> createState() => _VisualizerAnimationState();
}

class _VisualizerAnimationState extends State<_VisualizerAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(10 * (0.3 + 0.7 * math.sin(val * 2 * 3.14).abs())),
            _bar(10 * (0.2 + 0.8 * math.sin((val + 0.3) * 2 * 3.14).abs())),
            _bar(10 * (0.4 + 0.6 * math.sin((val + 0.6) * 2 * 3.14).abs())),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

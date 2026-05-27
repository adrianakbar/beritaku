import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../models/news_article.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_widgets.dart';
import 'article_detail_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final StorageService _storage = StorageService();

  List<NewsArticle> _savedArticles = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    setState(() => _isLoading = true);
    await _storage.init();
    final articles = await _storage.loadSavedArticles();
    setState(() {
      _savedArticles = articles;
      _isLoading = false;
    });
  }

  Future<void> _deleteBookmark(String id) async {
    await _storage.removeArticleOffline(id);
    _loadSaved();
    _showToast('Artikel dihapus dari luring');
  }

  List<NewsArticle> _getFilteredArticles() {
    if (_searchQuery.trim().isEmpty) return _savedArticles;
    final query = _searchQuery.toLowerCase();
    
    return _savedArticles.where((element) {
      return element.title.toLowerCase().contains(query) ||
          element.description.toLowerCase().contains(query) ||
          element.content.toLowerCase().contains(query) ||
          element.sourceName.toLowerCase().contains(query);
    }).toList();
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy HH:mm').format(date);
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perpustakaan Luring',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_savedArticles.length} artikel tersimpan offline',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.04),
                child: const Icon(Icons.wifi_off_rounded, color: Colors.black54, size: 20),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          GlassContainer(
            borderRadius: 16.0,
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 0.0),
            opacity: 0.16,
            child: TextField(
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Cari konten offline Anda...',
                hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                icon: Icon(Icons.saved_search_rounded, color: Colors.black45, size: 22),
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

          // Main body
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadSaved,
              color: const Color(0xFF6366F1),
              backgroundColor: Colors.white,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.only(bottom: 40),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final article = filtered[index];
                            return _buildOfflineCard(article);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.offline_pin_outlined, size: 60, color: Colors.black26),
            const SizedBox(height: 14),
            Text(
              _savedArticles.isEmpty ? 'Perpustakaan Anda Kosong' : 'Tidak ada hasil pencarian',
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                _savedArticles.isEmpty 
                    ? 'Klik ikon bookmark pada artikel berita di Beranda untuk mengunduhnya ke penyimpanan luring HP Anda.'
                    : 'Tidak menemukan artikel kustom dengan kata kunci tersebut di dalam penyimpanan lokal.',
                style: const TextStyle(color: Colors.black45, fontSize: 11, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineCard(NewsArticle article) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Dismissible(
        key: Key(article.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28),
        ),
        onDismissed: (_) => _deleteBookmark(article.id),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArticleDetailScreen(article: article),
              ),
            ).then((value) => _loadSaved());
          },
          borderRadius: BorderRadius.circular(20),
          child: GlassContainer(
            borderRadius: 20,
            opacity: 0.2,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (article.sentimentCategory != null)
                            SentimentBadge(category: article.sentimentCategory, compact: true),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                      Row(
                        children: [
                          const Icon(Icons.download_done_rounded, color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                          const Text(
                            'Offline Tersimpan',
                            style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(article.publishedAt),
                            style: const TextStyle(color: Colors.black38, fontSize: 9),
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
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: Image.network(
                        article.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.black.withOpacity(0.02)),
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

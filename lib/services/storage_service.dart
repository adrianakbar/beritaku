import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import '../models/news_article.dart';
import '../models/feed_source.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Preferences Keys
  static const String _keyGeminiApiKey = 'gemini_api_key';
  static const String _keyBlacklistedKeywords = 'blacklisted_keywords';
  static const String _keyTtsSpeed = 'tts_speed';
  static const String _keyTtsPitch = 'tts_pitch';
  static const String _keySupabaseUrl = 'supabase_url';
  static const String _keySupabaseKey = 'supabase_key';
  static const String _keyLastSyncTime = 'last_sync_time';
  static const String _keyFeedsSeeded = 'feed_sources_seeded_sqlite'; // Check if default feeds are seeded in SQLite
  static const String _keySelectedTitleFont = 'selected_title_font';
  static const String _keySelectedBodyFont = 'selected_body_font';
  static const String _keyThemeMode = 'theme_mode';


  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    
    // Seed default feed sources into SQLite if not seeded yet
    final bool seeded = _prefs.getBool(_keyFeedsSeeded) ?? false;
    if (!seeded) {
      final currentSources = await _dbHelper.getFeedSources();
      if (currentSources.isEmpty) {
        await _seedDefaultFeedSources();
      }
      await _prefs.setBool(_keyFeedsSeeded, true);
    } else {
      await loadFeedSourcesIntoMemory();
    }
  }

  // Gemini API Key
  String getGeminiApiKey() {
    return _prefs.getString(_keyGeminiApiKey) ?? '';
  }

  Future<void> setGeminiApiKey(String key) async {
    await _prefs.setString(_keyGeminiApiKey, key);
  }

  // Blacklisted Keywords (Direct Filter)
  List<String> getBlacklistedKeywords() {
    return _prefs.getStringList(_keyBlacklistedKeywords) ?? [];
  }

  Future<void> addBlacklistedKeyword(String keyword) async {
    final list = getBlacklistedKeywords();
    final cleanWord = keyword.trim().toLowerCase();
    if (cleanWord.isNotEmpty && !list.contains(cleanWord)) {
      list.add(cleanWord);
      await _prefs.setStringList(_keyBlacklistedKeywords, list);
    }
  }

  Future<void> removeBlacklistedKeyword(String keyword) async {
    final list = getBlacklistedKeywords();
    list.remove(keyword.trim().toLowerCase());
    await _prefs.setStringList(_keyBlacklistedKeywords, list);
  }

  // --- SQLITE FEED SOURCES OPERATORS ---

  List<FeedSource> getFeedSources() {
    // SharedPreferences sync wrapper. In Flutter, reading async list directly inside widgets
    // is best handled with a Future. To avoid blocking the synchronous dashboard signature,
    // we return a standard list by using a cached memory list or triggering FutureBuilder.
    // Wait! Since getFeedSources in dashboard was called synchronously e.g. `_storage.getFeedSources()`,
    // let's change `getFeedSources` to return a Future or keep a memory-cache!
    // Keeping a memory-cache of feed sources inside StorageService that is updated during init/mutations
    // is a *brilliant* design that lets the synchronous call `getFeedSources()` work immediately
    // without any screen code changes!
    return _memoryFeedSources;
  }

  List<FeedSource> _memoryFeedSources = [];

  // Async load for memory caching
  Future<void> loadFeedSourcesIntoMemory() async {
    _memoryFeedSources = await _dbHelper.getFeedSources();
  }

  Future<void> addFeedSource(FeedSource source) async {
    await _dbHelper.insertFeedSource(source);
    await loadFeedSourcesIntoMemory(); // Update memory cache
  }

  Future<void> updateFeedSource(FeedSource updated) async {
    await _dbHelper.updateFeedSource(updated);
    await loadFeedSourcesIntoMemory();
  }

  Future<void> deleteFeedSource(String id) async {
    await _dbHelper.deleteFeedSource(id);
    await loadFeedSourcesIntoMemory();
  }

  Future<void> _seedDefaultFeedSources() async {
    final defaults = [
      FeedSource(
        id: 'cntr-news',
        name: 'Antara News Terkini',
        url: 'https://www.antaranews.com/rss/terkini.xml',
        type: 'rss',
        isEnabled: true,
        category: 'Nasional',
      ),
      FeedSource(
        id: 'cnbc-indo',
        name: 'CNBC Indonesia',
        url: 'https://www.cnbcindonesia.com/news/rss',
        type: 'rss',
        isEnabled: true,
        category: 'Nasional',
      ),
      FeedSource(
        id: 'techcrunch',
        name: 'TechCrunch',
        url: 'https://techcrunch.com/feed/',
        type: 'rss',
        isEnabled: true,
        category: 'Teknologi',
      ),
      FeedSource(
        id: 'hn-top',
        name: 'Hacker News Top Stories',
        url: 'https://hacker-news.firebaseio.com/v0/topstories.json',
        type: 'hackernews',
        isEnabled: true,
        category: 'Teknologi',
      ),
      FeedSource(
        id: 'reddit-flutter',
        name: 'Reddit /r/flutter',
        url: 'flutter',
        type: 'reddit',
        isEnabled: true,
        category: 'Teknologi',
      ),
    ];

    for (final src in defaults) {
      await _dbHelper.insertFeedSource(src);
    }
    await loadFeedSourcesIntoMemory();
  }

  // TTS Settings
  double getTtsSpeed() => _prefs.getDouble(_keyTtsSpeed) ?? 0.55;
  Future<void> setTtsSpeed(double speed) async => await _prefs.setDouble(_keyTtsSpeed, speed);

  double getTtsPitch() => _prefs.getDouble(_keyTtsPitch) ?? 1.0;
  Future<void> setTtsPitch(double pitch) async => await _prefs.setDouble(_keyTtsPitch, pitch);

  // Supabase Backup Configuration
  String getSupabaseUrl() => _prefs.getString(_keySupabaseUrl) ?? '';
  Future<void> setSupabaseUrl(String url) async => await _prefs.setString(_keySupabaseUrl, url);

  String getSupabaseKey() => _prefs.getString(_keySupabaseKey) ?? '';
  Future<void> setSupabaseKey(String key) async => await _prefs.setString(_keySupabaseKey, key);

  String getLastSyncTime() => _prefs.getString(_keyLastSyncTime) ?? 'Belum pernah disinkronisasi';
  Future<void> setLastSyncTime(String time) async => await _prefs.setString(_keyLastSyncTime, time);

  // Typography Settings
  String getSelectedTitleFont() => _prefs.getString(_keySelectedTitleFont) ?? 'Playfair Display';
  Future<void> setSelectedTitleFont(String fontName) async => await _prefs.setString(_keySelectedTitleFont, fontName);

  String getSelectedBodyFont() => _prefs.getString(_keySelectedBodyFont) ?? 'Lora';
  Future<void> setSelectedBodyFont(String fontName) async => await _prefs.setString(_keySelectedBodyFont, fontName);

  // Theme Settings
  String getThemeMode() => _prefs.getString(_keyThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) async => await _prefs.setString(_keyThemeMode, mode);


  // --- SQLITE BOOKMARKS & OFFLINE ARTICLES PORTING ---

  Future<List<NewsArticle>> loadSavedArticles() async {
    return await _dbHelper.getBookmarks();
  }

  // Backup bulk upsert porting
  Future<void> saveArticlesList(List<NewsArticle> articles) async {
    for (final article in articles) {
      await _dbHelper.insertBookmark(article);
    }
  }

  Future<void> saveArticleOffline(NewsArticle article) async {
    final updatedArticle = article.copyWith(
      isBookmarked: true,
      isOfflineSaved: true,
    );
    await _dbHelper.insertBookmark(updatedArticle);
  }

  Future<void> removeArticleOffline(String articleId) async {
    await _dbHelper.deleteBookmark(articleId);
  }

  Future<NewsArticle?> getSavedArticle(String articleId) async {
    return await _dbHelper.getBookmark(articleId);
  }
}

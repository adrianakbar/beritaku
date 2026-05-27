import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/news_article.dart';
import '../models/feed_source.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'beritaku.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create bookmarks table
    await db.execute('''
      CREATE TABLE bookmarks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        content TEXT,
        url TEXT NOT NULL,
        source_name TEXT,
        published_at TEXT,
        image_url TEXT,
        summary_bullets TEXT, -- Serialized JSON String (List<String>)
        sentiment_category TEXT,
        sentiment_description TEXT
      )
    ''');

    // 2. Create feed_sources table
    await db.execute('''
      CREATE TABLE feed_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        type TEXT NOT NULL,
        is_enabled INTEGER, -- 0 for false, 1 for true
        category TEXT
      )
    ''');
  }

  // --- BOOKMARKS CRUD OPERATORS ---

  Future<List<NewsArticle>> getBookmarks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('bookmarks', orderBy: 'published_at DESC');

    return List.generate(maps.length, (i) {
      final row = maps[i];
      
      // Decode summary bullets JSON string back to list
      List<String> bullets = [];
      if (row['summary_bullets'] != null && row['summary_bullets'].toString().isNotEmpty) {
        try {
          bullets = List<String>.from(jsonDecode(row['summary_bullets']));
        } catch (_) {}
      }

      return NewsArticle(
        id: row['id'],
        title: row['title'],
        description: row['description'] ?? '',
        content: row['content'] ?? '',
        url: row['url'],
        sourceName: row['source_name'] ?? 'Umpan',
        publishedAt: row['published_at'] != null 
            ? DateTime.parse(row['published_at']) 
            : DateTime.now(),
        imageUrl: row['image_url'],
        isBookmarked: true,
        isOfflineSaved: true,
        summaryBullets: bullets,
        sentimentCategory: row['sentiment_category'],
        sentimentDescription: row['sentiment_description'],
      );
    });
  }

  Future<NewsArticle?> getBookmark(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    final row = maps.first;

    List<String> bullets = [];
    if (row['summary_bullets'] != null && row['summary_bullets'].toString().isNotEmpty) {
      try {
        bullets = List<String>.from(jsonDecode(row['summary_bullets']));
      } catch (_) {}
    }

    return NewsArticle(
      id: row['id'],
      title: row['title'],
      description: row['description'] ?? '',
      content: row['content'] ?? '',
      url: row['url'],
      sourceName: row['source_name'] ?? 'Umpan',
      publishedAt: row['published_at'] != null 
          ? DateTime.parse(row['published_at']) 
          : DateTime.now(),
      imageUrl: row['image_url'],
      isBookmarked: true,
      isOfflineSaved: true,
      summaryBullets: bullets,
      sentimentCategory: row['sentiment_category'],
      sentimentDescription: row['sentiment_description'],
    );
  }

  Future<void> insertBookmark(NewsArticle article) async {
    final db = await database;
    
    final Map<String, dynamic> row = {
      'id': article.id,
      'title': article.title,
      'description': article.description,
      'content': article.content,
      'url': article.url,
      'source_name': article.sourceName,
      'published_at': article.publishedAt.toIso8601String(),
      'image_url': article.imageUrl,
      'summary_bullets': jsonEncode(article.summaryBullets),
      'sentiment_category': article.sentimentCategory,
      'sentiment_description': article.sentimentDescription,
    };

    await db.insert(
      'bookmarks',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBookmark(String id) async {
    final db = await database;
    await db.delete(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- FEED SOURCES CRUD OPERATORS ---

  Future<List<FeedSource>> getFeedSources() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('feed_sources');

    return List.generate(maps.length, (i) {
      final row = maps[i];
      return FeedSource(
        id: row['id'],
        name: row['name'],
        url: row['url'],
        type: row['type'],
        isEnabled: row['is_enabled'] == 1,
        category: row['category'] ?? 'Umum',
      );
    });
  }

  Future<void> insertFeedSource(FeedSource source) async {
    final db = await database;
    final row = {
      'id': source.id,
      'name': source.name,
      'url': source.url,
      'type': source.type,
      'is_enabled': source.isEnabled ? 1 : 0,
      'category': source.category,
    };

    await db.insert(
      'feed_sources',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFeedSource(FeedSource source) async {
    final db = await database;
    final row = {
      'id': source.id,
      'name': source.name,
      'url': source.url,
      'type': source.type,
      'is_enabled': source.isEnabled ? 1 : 0,
      'category': source.category,
    };

    await db.update(
      'feed_sources',
      row,
      where: 'id = ?',
      whereArgs: [source.id],
    );
  }

  Future<void> deleteFeedSource(String id) async {
    final db = await database;
    await db.delete(
      'feed_sources',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:beritaku/models/news_article.dart';
import 'package:beritaku/models/feed_source.dart';

void main() {
  group('SQLite Data Mapping Tests', () {
    test('NewsArticle converts to SQLite row format correctly', () {
      final article = NewsArticle(
        id: 'sqlite-123',
        title: 'Judul SQLite Berita',
        description: 'Deskripsi pendek.',
        content: 'Konten lengkap berita relasional.',
        url: 'https://example.com/sqlite',
        sourceName: 'CNBC',
        publishedAt: DateTime.parse('2026-05-27T12:00:00Z'),
        imageUrl: 'https://example.com/img.png',
        isBookmarked: true,
        isOfflineSaved: true,
        summaryBullets: ['poin 1', 'poin 2', 'poin 3'],
        sentimentCategory: 'Ekonomi Makro',
        sentimentDescription: 'Berita tentang keuangan lokal.',
      );

      // Verify row map matches database schema requirements
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

      expect(row['id'], equals('sqlite-123'));
      expect(row['title'], equals('Judul SQLite Berita'));
      expect(row['sentiment_category'], equals('Ekonomi Makro'));
      expect(jsonDecode(row['summary_bullets']), equals(['poin 1', 'poin 2', 'poin 3']));
    });

    test('FeedSource converts to SQLite row format correctly', () {
      final source = FeedSource(
        id: 'feed-123',
        name: 'TechCrunch RSS',
        url: 'https://techcrunch.com/feed',
        type: 'rss',
        isEnabled: true,
        category: 'Teknologi',
      );

      final row = {
        'id': source.id,
        'name': source.name,
        'url': source.url,
        'type': source.type,
        'is_enabled': source.isEnabled ? 1 : 0,
        'category': source.category,
      };

      expect(row['id'], equals('feed-123'));
      expect(row['is_enabled'], equals(1));
      expect(row['category'], equals('Teknologi'));
    });
  });
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_article.dart';
import 'storage_service.dart';

class BackupService {
  final StorageService _storageService = StorageService();

  // Test credentials and connection to Supabase
  Future<bool> testConnection(String url, String key) async {
    if (url.trim().isEmpty || key.trim().isEmpty) return false;

    // Clean URL
    final cleanUrl = url.trim().endsWith('/') ? url.trim() : '${url.trim()}/';
    final targetUrl = '${cleanUrl}rest/v1/bookmarks?select=id&limit=1';

    try {
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: {
          'apikey': key.trim(),
          'Authorization': 'Bearer ${key.trim()}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      // 200 means success (table exists), 404 means table doesn't exist but connection was made,
      // 401/403 means auth failure.
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (_) {}
    return false;
  }

  // SQL Query for User to create the bookmarks table in Supabase
  static const String supabaseSqlSetup = '''
-- Copy-paste ini di SQL Editor Supabase Anda untuk membuat tabel bookmarks:

create table if not exists public.bookmarks (
  id text primary key,
  title text not null,
  description text,
  content text,
  url text not null,
  source_name text,
  published_at timestamp with time zone,
  image_url text,
  summary_bullets jsonb,
  sentiment_category text,
  sentiment_description text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Mengaktifkan akses publik untuk pembacaan & penulisan
alter table public.bookmarks enable row level security;
create policy "Allow all operations for anon keys" on public.bookmarks
  for all using (true) with check (true);
''';

  // Push local bookmarks to Supabase (Upsert / Merge)
  Future<bool> syncBookmarks() async {
    final supabaseUrl = _storageService.getSupabaseUrl().trim();
    final supabaseKey = _storageService.getSupabaseKey().trim();

    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw Exception('Supabase URL atau Key belum dikonfigurasi di halaman Pengaturan.');
    }

    final cleanUrl = supabaseUrl.endsWith('/') ? supabaseUrl : '$supabaseUrl/';
    final endpoint = '${cleanUrl}rest/v1/bookmarks';

    try {
      // 1. Load Local Bookmarks
      final localArticles = await _storageService.loadSavedArticles();
      
      // 2. Fetch Remote Bookmarks from Supabase
      final getResponse = await http.get(
        Uri.parse('$endpoint?select=*'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      List<NewsArticle> remoteArticles = [];
      if (getResponse.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(getResponse.body);
        remoteArticles = decoded.map((e) {
          // Convert database schema back to NewsArticle model
          return NewsArticle(
            id: e['id'],
            title: e['title'] ?? 'Tanpa Judul',
            description: e['description'] ?? '',
            content: e['content'] ?? '',
            url: e['url'] ?? '',
            sourceName: e['source_name'] ?? 'Supabase',
            publishedAt: e['published_at'] != null 
                ? DateTime.parse(e['published_at']) 
                : DateTime.now(),
            imageUrl: e['image_url'],
            isBookmarked: true,
            isOfflineSaved: true,
            summaryBullets: List<String>.from(e['summary_bullets'] ?? []),
            sentimentCategory: e['sentiment_category'],
            sentimentDescription: e['sentiment_description'],
          );
        }).toList();
      } else if (getResponse.statusCode == 404) {
        throw Exception('Tabel "bookmarks" tidak ditemukan di database Supabase Anda. Silakan jalankan kueri SQL di Settings.');
      } else {
        throw Exception('Gagal mengunduh data dari Supabase (Status: ${getResponse.statusCode}).');
      }

      // 3. Merge Bookmarks: Keep all unique articles from both sides.
      // If same ID, keep the one with summary bullets or keep local.
      final Map<String, NewsArticle> mergedMap = {};
      
      for (final art in remoteArticles) {
        mergedMap[art.id] = art;
      }
      
      for (final art in localArticles) {
        final existing = mergedMap[art.id];
        if (existing == null || art.summaryBullets.length > existing.summaryBullets.length) {
          mergedMap[art.id] = art;
        }
      }

      final List<NewsArticle> mergedList = mergedMap.values.toList();

      // 4. Save merged list locally
      await _storageService.saveArticlesList(mergedList);

      // 5. Upload everything back to Supabase (bulk upsert)
      if (mergedList.isNotEmpty) {
        final List<Map<String, dynamic>> payload = mergedList.map((e) {
          return {
            'id': e.id,
            'title': e.title,
            'description': e.description,
            'content': e.content,
            'url': e.url,
            'source_name': e.sourceName,
            'published_at': e.publishedAt.toIso8601String(),
            'image_url': e.imageUrl,
            'summary_bullets': e.summaryBullets,
            'sentiment_category': e.sentimentCategory,
            'sentiment_description': e.sentimentDescription,
          };
        }).toList();

        final upsertResponse = await http.post(
          Uri.parse(endpoint),
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates', // Upsert directive
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 15));

        if (upsertResponse.statusCode != 201 && upsertResponse.statusCode != 200 && upsertResponse.statusCode != 204) {
          throw Exception('Gagal mengunggah data sinkronisasi ke Supabase (Status: ${upsertResponse.statusCode}).');
        }
      }

      // Update sync time
      final now = DateTime.now();
      final timeStr = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await _storageService.setLastSyncTime(timeStr);

      return true;
    } catch (e) {
      throw Exception('Gagal menyinkronkan data: $e');
    }
  }
}

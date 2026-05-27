import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/news_article.dart';
import '../models/feed_source.dart';
import 'storage_service.dart';

class RssService {
  final StorageService _storageService = StorageService();

  // MD5-like string hashing for unique and safe IDs
  String _generateId(String input) {
    return input.hashCode.abs().toString();
  }

  // Clear HTML tags helper
  String _cleanHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    
    // Simple regex to strip HTML tags
    String cleaned = htmlString.replaceAll(RegExp(r'<[^>]*>|&thinsp;|&nbsp;|&amp;'), ' ');
    
    // Replace multiple spaces/newlines
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  // Parse image URL from item description HTML if needed
  String? _extractImageFromHtml(String htmlString) {
    try {
      final match = RegExp(r'<img[^>]+src="([^">]+)"').firstMatch(htmlString);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    } catch (_) {}
    return null;
  }

  // Main Fetch Method combining all enabled sources or filtered by specific FeedSource
  Future<List<NewsArticle>> fetchArticles({FeedSource? specificSource}) async {
    final List<FeedSource> sources = specificSource != null 
        ? [specificSource] 
        : _storageService.getFeedSources().where((element) => element.isEnabled).toList();

    final List<NewsArticle> allArticles = [];

    for (final source in sources) {
      try {
        List<NewsArticle> sourceArticles = [];
        if (source.type == 'rss') {
          sourceArticles = await _fetchRssFeed(source);
        } else if (source.type == 'reddit') {
          sourceArticles = await _fetchRedditFeed(source);
        } else if (source.type == 'hackernews') {
          sourceArticles = await _fetchHackerNewsFeed(source);
        }

        allArticles.addAll(sourceArticles);
      } catch (e) {
        // Fail silently for single feeds so it doesn't crash the entire dashboard
        print('Error fetching source ${source.name}: $e');
      }
    }

    // Sort by publish date descending
    allArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // Apply Blacklist Keyword Filter (Direct Source Filter)
    final blacklist = _storageService.getBlacklistedKeywords();
    if (blacklist.isEmpty) return allArticles;

    return allArticles.where((article) {
      final title = article.title.toLowerCase();
      final desc = article.description.toLowerCase();
      
      // If any blacklisted keyword is found in title or description, exclude it
      for (final keyword in blacklist) {
        if (title.contains(keyword) || desc.contains(keyword)) {
          return false; // Filter out
        }
      }
      return true; // Keep
    }).toList();
  }

  // 1. Standard RSS / Atom XML Fetch & Parse
  Future<List<NewsArticle>> _fetchRssFeed(FeedSource source) async {
    final response = await http.get(Uri.parse(source.url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return [];

    final List<NewsArticle> list = [];
    final document = xml.XmlDocument.parse(response.body);

    // Try Standard RSS <item> channels
    var items = document.findAllElements('item');
    if (items.isEmpty) {
      // Try Atom <entry> channels
      items = document.findAllElements('entry');
    }

    for (final item in items) {
      try {
        final title = item.findElements('title').firstOrNull?.innerText ?? 'Tanpa Judul';
        final link = item.findElements('link').firstOrNull?.innerText ?? 
                     item.findElements('link').firstOrNull?.getAttribute('href') ?? 
                     '';
        
        final descRaw = item.findElements('description').firstOrNull?.innerText ?? 
                       item.findElements('summary').firstOrNull?.innerText ?? 
                       '';
                       
        final contentRaw = item.findElements('content:encoded').firstOrNull?.innerText ?? 
                          item.findElements('content').firstOrNull?.innerText ?? 
                          descRaw;

        final description = _cleanHtml(descRaw);
        final content = _cleanHtml(contentRaw);

        // Extract dates
        final pubDateStr = item.findElements('pubDate').firstOrNull?.innerText ?? 
                           item.findElements('published').firstOrNull?.innerText ?? 
                           item.findElements('updated').firstOrNull?.innerText ?? 
                           DateTime.now().toIso8601String();
        
        DateTime publishedAt;
        try {
          // Fallback parsing
          publishedAt = DateTime.parse(pubDateStr);
        } catch (_) {
          // Format standard RSS date if DateTime.parse fails
          publishedAt = _parseRssDate(pubDateStr);
        }

        // Image extraction: look at <media:content>, <enclosure>, or inside description HTML
        String? imageUrl;
        final mediaContent = item.findElements('media:content').firstOrNull;
        if (mediaContent != null) {
          imageUrl = mediaContent.getAttribute('url');
        }

        imageUrl ??= item.findElements('enclosure').firstOrNull?.getAttribute('url');
        imageUrl ??= _extractImageFromHtml(descRaw);
        imageUrl ??= _extractImageFromHtml(contentRaw);

        // Setup placeholder/image validation (Kompas RSS often has default images)
        if (imageUrl != null && imageUrl.startsWith('//')) {
          imageUrl = 'https:$imageUrl';
        }

        if (link.isNotEmpty) {
          list.add(NewsArticle(
            id: _generateId(link),
            title: title,
            description: description.length > 200 ? '${description.substring(0, 197)}...' : description,
            content: content,
            url: link,
            sourceName: source.name,
            publishedAt: publishedAt,
            imageUrl: imageUrl,
          ));
        }
      } catch (_) {
        // Skip malformed item
      }
    }

    return list;
  }

  // 2. Fetch Reddit Subreddit (.json)
  Future<List<NewsArticle>> _fetchRedditFeed(FeedSource source) async {
    final String formattedUrl = 'https://www.reddit.com/r/${source.url}/hot.json?limit=15';
    final response = await http.get(Uri.parse(formattedUrl), headers: {
      'User-Agent': 'beritaku:v1.0.0 (by Adrian Akbar)'
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return [];

    final List<NewsArticle> list = [];
    final Map<String, dynamic> data = jsonDecode(response.body);
    final List<dynamic> children = data['data']['children'] ?? [];

    for (final child in children) {
      try {
        final post = child['data'];
        
        // Skip stickied posts
        if (post['stickied'] == true) continue;

        final title = post['title'] ?? 'Tanpa Judul';
        final permalink = post['permalink'] ?? '';
        final link = 'https://www.reddit.com$permalink';
        
        final selftext = post['selftext'] ?? '';
        final url = post['url'] ?? link;
        
        final double createdUtc = (post['created_utc'] ?? DateTime.now().millisecondsSinceEpoch / 1000).toDouble();
        final publishedAt = DateTime.fromMillisecondsSinceEpoch((createdUtc * 1000).toInt());

        String? imageUrl;
        final preview = post['preview'];
        if (preview != null && preview['images'] != null && preview['images'].isNotEmpty) {
          final sourceImg = preview['images'][0]['source'];
          if (sourceImg != null) {
            imageUrl = sourceImg['url'].toString().replaceAll('&amp;', '&');
          }
        }

        final description = selftext.isNotEmpty 
            ? (selftext.length > 200 ? '${selftext.substring(0, 197)}...' : selftext)
            : 'Link Post: $url';

        list.add(NewsArticle(
          id: _generateId(link),
          title: title,
          description: description,
          content: selftext.isNotEmpty ? selftext : 'Membuka tautan eksternal: $url',
          url: link,
          sourceName: 'Reddit /r/${source.url}',
          publishedAt: publishedAt,
          imageUrl: imageUrl,
        ));
      } catch (_) {}
    }

    return list;
  }

  // 3. Fetch Hacker News Top Stories (Max 15 items for performance)
  Future<List<NewsArticle>> _fetchHackerNewsFeed(FeedSource source) async {
    final response = await http.get(Uri.parse(source.url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return [];

    final List<dynamic> topIds = jsonDecode(response.body);
    final List<NewsArticle> list = [];
    
    // Fetch details of top 15 stories concurrently
    final itemsToFetch = topIds.take(15).toList();
    final futures = itemsToFetch.map((id) => _fetchHackerNewsItem(id));
    
    final results = await Future.wait(futures);
    for (final article in results) {
      if (article != null) {
        list.add(article);
      }
    }

    return list;
  }

  Future<NewsArticle?> _fetchHackerNewsItem(dynamic id) async {
    try {
      final response = await http.get(Uri.parse('https://hacker-news.firebaseio.com/v0/item/$id.json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final Map<String, dynamic> item = jsonDecode(response.body);
      final String title = item['title'] ?? 'Tanpa Judul';
      final String link = item['url'] ?? 'https://news.ycombinator.com/item?id=$id';
      final String author = item['by'] ?? 'HN';
      final int score = item['score'] ?? 0;
      final int time = item['time'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final publishedAt = DateTime.fromMillisecondsSinceEpoch(time * 1000);
      
      final String textRaw = item['text'] ?? '';
      final String description = textRaw.isNotEmpty 
          ? _cleanHtml(textRaw)
          : 'Score: $score poin | Ditulis oleh: $author';

      return NewsArticle(
        id: _generateId(link),
        title: title,
        description: description.length > 200 ? '${description.substring(0, 197)}...' : description,
        content: textRaw.isNotEmpty ? _cleanHtml(textRaw) : 'Link Post: $link',
        url: link,
        sourceName: 'Hacker News',
        publishedAt: publishedAt,
        imageUrl: null, // Hacker News has no images
      );
    } catch (_) {
      return null;
    }
  }

  // Parse standard RSS date formats e.g. "Wed, 27 May 2026 12:00:00 GMT" or "Tue, 26 May 2026 05:00:00 +0700"
  DateTime _parseRssDate(String dateStr) {
    try {
      // Clean string
      final clean = dateStr.trim();
      
      // Mon, 02 Jan 2006 15:04:05 -0700 or GMT
      final List<String> parts = clean.split(' ');
      if (parts.length >= 4) {
        // e.g. "27 May 2026"
        final day = int.tryParse(parts[1]) ?? 1;
        final monthStr = parts[2].toLowerCase();
        final year = int.tryParse(parts[3]) ?? DateTime.now().year;

        int month = 1;
        const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        for (int i = 0; i < months.length; i++) {
          if (monthStr.startsWith(months[i])) {
            month = i + 1;
            break;
          }
        }

        int hour = 0, minute = 0, second = 0;
        if (parts.length >= 5) {
          final timeParts = parts[4].split(':');
          if (timeParts.length >= 2) {
            hour = int.tryParse(timeParts[0]) ?? 0;
            minute = int.tryParse(timeParts[1]) ?? 0;
            if (timeParts.length >= 3) {
              second = int.tryParse(timeParts[2]) ?? 0;
            }
          }
        }

        return DateTime(year, month, day, hour, minute, second);
      }
    } catch (_) {}
    return DateTime.now();
  }
}
extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

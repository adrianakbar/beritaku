import 'package:flutter_test/flutter_test.dart';
import 'package:beritaku/models/news_article.dart';

void main() {
  group('Keyword Blacklist Filter Tests', () {
    final list = [
      NewsArticle(
        id: '1',
        title: 'Bahas Politik Memanas Hari Ini',
        description: 'Update perwakilan partai nasional.',
        content: 'Konten lengkap mengenai pemilu.',
        url: 'https://example.com/1',
        sourceName: 'Nasional',
        publishedAt: DateTime.now(),
      ),
      NewsArticle(
        id: '2',
        title: 'Rekomendasi Framework Pemrograman',
        description: 'Flutter terpilih sebagai cross-platform terbaik.',
        content: 'Belajar mobile development sangat asyik.',
        url: 'https://example.com/2',
        sourceName: 'Teknologi',
        publishedAt: DateTime.now(),
      ),
      NewsArticle(
        id: '3',
        title: 'Gosip Artis Terkenal Menikah',
        description: 'Pesta mewah diadakan di Bali.',
        content: 'Dihadiri rekan sesama selebriti.',
        url: 'https://example.com/3',
        sourceName: 'Gosip',
        publishedAt: DateTime.now(),
      ),
    ];

    test('Filtering out exact keyword matches', () {
      final blacklist = ['politik', 'gosip'];
      
      final filtered = list.where((article) {
        final title = article.title.toLowerCase();
        final desc = article.description.toLowerCase();
        
        for (final keyword in blacklist) {
          if (title.contains(keyword) || desc.contains(keyword)) {
            return false; // Filter out
          }
        }
        return true; // Keep
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered[0].id, equals('2'));
      expect(filtered[0].title, contains('Framework Pemrograman'));
    });
  });
}

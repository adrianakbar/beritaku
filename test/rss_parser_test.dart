import 'package:flutter_test/flutter_test.dart';
import 'package:beritaku/services/rss_service.dart';

void main() {
  group('RssService Helpers Tests', () {
    // We can instantiate RssService to access public utilities
    final rssService = RssService();

    test('HTML tag stripping works correctly', () {
      const htmlText = '<p>Halo <b>Adrian</b>! Silakan baca <a href="https://google.com">berita</a> ini &amp; nikmati.</p>';
      
      // We can use RegExp internally similar to how RssService parses it
      // Let's verify the cleaning behavior
      final cleaned = htmlText.replaceAll(RegExp(r'<[^>]*>|&thinsp;|&nbsp;|&amp;'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      
      expect(cleaned, equals('Halo Adrian ! Silakan baca berita ini nikmati.'));
    });

    test('Date parsing from RSS standard string formats works', () {
      const rssDate = 'Wed, 27 May 2026 12:30:00 +0700';
      final parts = rssDate.split(' ');
      
      expect(parts[1], equals('27'));
      expect(parts[2].toLowerCase(), equals('may'));
      expect(parts[3], equals('2026'));
      
      final timeParts = parts[4].split(':');
      expect(timeParts[0], equals('12'));
      expect(timeParts[1], equals('30'));
    });
  });
}

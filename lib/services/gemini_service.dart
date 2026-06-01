import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news_article.dart';
import 'storage_service.dart';

class GeminiService {
  final StorageService _storageService = StorageService();

  // Test the connection with a simple prompt
  Future<bool> testConnection(String apiKey) async {
    if (apiKey.trim().isEmpty) return false;
    
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$apiKey';
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Katakan "OK" jika Anda menerima pesan ini.'}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String text = data['candidates'][0]['content']['parts'][0]['text'] ?? '';
        return text.isNotEmpty;
      }
    } catch (_) {}
    return false;
  }

  // Generates 3 bullets and sentiment analysis for a long news article
  Future<NewsArticle> analyzeArticle(NewsArticle article) async {
    // If already analyzed and cached, return it!
    if (article.summaryBullets.isNotEmpty && article.sentimentCategory != null) {
      return article;
    }

    final apiKey = _storageService.getGeminiApiKey();
    if (apiKey.isEmpty) {
      throw Exception('API Key Gemini belum dikonfigurasi. Silakan masuk ke halaman Pengaturan.');
    }

    final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$apiKey';

    // Prepare robust prompt for structured JSON output
    final String prompt = '''
Analisis berita berikut dan buat ringkasan dalam format JSON terstruktur.
Anda harus mengembalikan valid JSON objek dengan kunci persis seperti di bawah ini:
{
  "bullets": [
    "Poin ringkasan pertama dalam Bahasa Indonesia (maksimal 15 kata)",
    "Poin ringkasan kedua dalam Bahasa Indonesia (maksimal 15 kata)",
    "Poin ringkasan ketiga dalam Bahasa Indonesia (maksimal 15 kata)"
  ],
  "sentimentCategory": "pilih salah satu dari kategori berikut secara ketat: Politik Memanas, Ekonomi Makro, Sains & Teknologi, Gosip Ringan, Berita Umum",
  "sentimentDescription": "Satu kalimat penjelasan mengapa berita ini dimasukkan ke kategori tersebut dalam Bahasa Indonesia."
}

Berita yang akan dianalisis:
Judul: ${article.title}
Sumber: ${article.sourceName}
Deskripsi: ${article.description}
Konten Lengkap: ${article.content}
''';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
          }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String responseText = data['candidates'][0]['content']['parts'][0]['text'] ?? '{}';
        
        final Map<String, dynamic> parsedJson = jsonDecode(responseText.trim());
        
        final List<String> bullets = List<String>.from(parsedJson['bullets'] ?? []);
        final String sentimentCat = parsedJson['sentimentCategory'] ?? 'Berita Umum';
        final String sentimentDesc = parsedJson['sentimentDescription'] ?? 'Analisis berita selesai.';

        // Create updated article copy
        final analyzedArticle = article.copyWith(
          summaryBullets: bullets.isNotEmpty ? bullets : ['Gagal membuat poin ringkasan 1.', 'Gagal membuat poin ringkasan 2.', 'Gagal membuat poin ringkasan 3.'],
          sentimentCategory: sentimentCat,
          sentimentDescription: sentimentDesc,
        );

        // Auto-save/update cache in local bookmarks if it is bookmarked
        final saved = await _storageService.getSavedArticle(article.id);
        if (saved != null) {
          await _storageService.saveArticleOffline(analyzedArticle);
        }

        return analyzedArticle;
      } else {
        final errorMsg = jsonDecode(response.body)['error']?['message'] ?? 'Unknown Error';
        throw Exception('API Gemini Error: $errorMsg');
      }
    } catch (e) {
      throw Exception('Gagal menghubungi Gemini AI: $e');
    }
  }
}

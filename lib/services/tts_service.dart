import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/news_article.dart';
import 'storage_service.dart';

enum TtsState { playing, stopped, paused }

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  final StorageService _storageService = StorageService();

  TtsState _ttsState = TtsState.stopped;
  TtsState get ttsState => _ttsState;

  bool get isPlaying => _ttsState == TtsState.playing;
  bool get isPaused => _ttsState == TtsState.paused;
  bool get isStopped => _ttsState == TtsState.stopped;

  NewsArticle? _currentArticle;
  NewsArticle? get currentArticle => _currentArticle;

  // Callback to signal the UI when the current article reading completes
  VoidCallback? _onCompletionCallback;

  TtsService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    // Basic completion and state handlers
    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
      notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      notifyListeners();
      if (_onCompletionCallback != null) {
        _onCompletionCallback!();
      }
    });

    _flutterTts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
      notifyListeners();
    });

    _flutterTts.setPauseHandler(() {
      _ttsState = TtsState.paused;
      notifyListeners();
    });

    _flutterTts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
      notifyListeners();
    });

    // Default language is Indonesian (id-ID)
    await _flutterTts.setLanguage("id-ID");
    
    // Set engine if Android (best for Indonesian Google Assistant voice)
    if (!kIsWeb) {
      try {
        await _flutterTts.setEngine("com.google.android.tts");
      } catch (_) {}
    }
  }

  // Register a playlist auto-advance callback
  void setCompletionCallback(VoidCallback callback) {
    _onCompletionCallback = callback;
  }

  void removeCompletionCallback() {
    _onCompletionCallback = null;
  }

  // Starts speaking a NewsArticle
  Future<void> speakArticle(NewsArticle article) async {
    if (_currentArticle?.id == article.id && _ttsState == TtsState.paused) {
      await resume();
      return;
    }

    await stop();
    _currentArticle = article;

    // Apply speed and pitch settings from storage
    final speed = _storageService.getTtsSpeed();
    final pitch = _storageService.getTtsPitch();
    await _flutterTts.setSpeechRate(speed);
    await _flutterTts.setPitch(pitch);

    // Prepare text to read (reads title, summary bullets if available, then full content)
    final StringBuffer buffer = StringBuffer();
    buffer.write("Membacakan berita: ${article.title}. ");
    buffer.write("Dari sumber: ${article.sourceName}. ");
    
    if (article.summaryBullets.isNotEmpty) {
      buffer.write("Ringkasan inti berita: ");
      for (final bullet in article.summaryBullets) {
        buffer.write("$bullet. ");
      }
    }

    buffer.write("Isi berita lengkap: ");
    buffer.write(article.content);

    // Speak!
    await _flutterTts.speak(buffer.toString());
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    _ttsState = TtsState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_currentArticle != null) {
      _ttsState = TtsState.playing;
      notifyListeners();
      await _flutterTts.speak(_currentArticle!.title); // dummy resume trigger depending on engine, standard flutter_tts handles direct resume well
      // Wait, in flutter_tts, speaking again or direct engine resumes works.
      // Better approach: Speak the buffer starting from beginning, or if supported, resume
      // Since native engines handle TTS resumes differently, let's just speak again or call speak on the full text
      await speakArticle(_currentArticle!);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _ttsState = TtsState.stopped;
    notifyListeners();
  }

  // Set Speed (0.0 to 1.0)
  Future<void> setSpeed(double rate) async {
    await _storageService.setTtsSpeed(rate);
    await _flutterTts.setSpeechRate(rate);
    notifyListeners();
  }

  // Set Pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    await _storageService.setTtsPitch(pitch);
    await _flutterTts.setPitch(pitch);
    notifyListeners();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}

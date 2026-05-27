import 'dart:convert';

class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String content;
  final String url;
  final String sourceName;
  final DateTime publishedAt;
  final String? imageUrl;
  final bool isBookmarked;
  final bool isOfflineSaved;
  final List<String> summaryBullets;
  final String? sentimentCategory;
  final String? sentimentDescription;

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.url,
    required this.sourceName,
    required this.publishedAt,
    this.imageUrl,
    this.isBookmarked = false,
    this.isOfflineSaved = false,
    this.summaryBullets = const [],
    this.sentimentCategory,
    this.sentimentDescription,
  });

  NewsArticle copyWith({
    String? id,
    String? title,
    String? description,
    String? content,
    String? url,
    String? sourceName,
    DateTime? publishedAt,
    String? imageUrl,
    bool? isBookmarked,
    bool? isOfflineSaved,
    List<String>? summaryBullets,
    String? sentimentCategory,
    String? sentimentDescription,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      url: url ?? this.url,
      sourceName: sourceName ?? this.sourceName,
      publishedAt: publishedAt ?? this.publishedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isOfflineSaved: isOfflineSaved ?? this.isOfflineSaved,
      summaryBullets: summaryBullets ?? this.summaryBullets,
      sentimentCategory: sentimentCategory ?? this.sentimentCategory,
      sentimentDescription: sentimentDescription ?? this.sentimentDescription,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'url': url,
      'sourceName': sourceName,
      'publishedAt': publishedAt.toIso8601String(),
      'imageUrl': imageUrl,
      'isBookmarked': isBookmarked,
      'isOfflineSaved': isOfflineSaved,
      'summaryBullets': summaryBullets,
      'sentimentCategory': sentimentCategory,
      'sentimentDescription': sentimentDescription,
    };
  }

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      content: json['content'] as String,
      url: json['url'] as String,
      sourceName: json['sourceName'] as String,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      imageUrl: json['imageUrl'] as String?,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      isOfflineSaved: json['isOfflineSaved'] as bool? ?? false,
      summaryBullets: List<String>.from(json['summaryBullets'] ?? []),
      sentimentCategory: json['sentimentCategory'] as String?,
      sentimentDescription: json['sentimentDescription'] as String?,
    );
  }
}

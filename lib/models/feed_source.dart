class FeedSource {
  final String id;
  final String name;
  final String url;
  final String type; // 'rss', 'reddit', 'hackernews'
  final bool isEnabled;
  final String category; // 'Teknologi', 'Nasional', 'Hobi', dll.

  FeedSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.isEnabled = true,
    this.category = 'Umum',
  });

  FeedSource copyWith({
    String? id,
    String? name,
    String? url,
    String? type,
    bool? isEnabled,
    String? category,
  }) {
    return FeedSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      isEnabled: isEnabled ?? this.isEnabled,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'isEnabled': isEnabled,
      'category': category,
    };
  }

  factory FeedSource.fromJson(Map<String, dynamic> json) {
    return FeedSource(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      type: json['type'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
      category: json['category'] as String? ?? 'Umum',
    );
  }
}

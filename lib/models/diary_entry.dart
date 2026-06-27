import 'emotion.dart';

/// 日记条目数据类
///
/// 记录用户与宠物的互动日记，支持情绪标签、收藏等。
class DiaryEntry {
  final int? id;           // 数据库自增主键
  final String content;    // 日记正文
  final DateTime createdAt;
  final Emotion mood;      // 记录时的心情
  final List<String> tags; // 标签列表
  bool isFavorite;         // 是否收藏

  DiaryEntry({
    this.id,
    required this.content,
    DateTime? createdAt,
    this.mood = Emotion.neutral,
    List<String>? tags,
    this.isFavorite = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        tags = tags ?? [];

  // ========== 计算属性 ==========
  /// 日记日期（仅日期部分）
  DateTime get date => DateTime(createdAt.year, createdAt.month, createdAt.day);

  /// 内容预览（截取前50字）
  String get preview {
    if (content.length <= 50) return content;
    return '${content.substring(0, 50)}...';
  }

  /// 字数
  int get wordCount => content.replaceAll(RegExp(r'\s+'), '').length;

  /// 情绪 emoji
  String get moodEmoji => mood.emoji;

  /// 情绪中文
  String get moodLabel => mood.label;

  // ========== 数据验证 ==========
  /// 验证日记内容是否有效
  static String? validate(String content) {
    if (content.trim().isEmpty) {
      return '日记内容不能为空';
    }
    if (content.trim().length < 2) {
      return '日记内容太短，至少写点什么吧~';
    }
    if (content.length > 5000) {
      return '日记内容不能超过5000字';
    }
    return null; // 验证通过
  }

  // ========== JSON 序列化 ==========
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'mood': mood.index,
      'tags': tags.join(','),
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  /// 从 sqflite 查询结果构建
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as int?,
      content: json['content'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      mood: Emotion.values[json['mood'] as int? ?? 6],
      tags: _parseTags(json['tags'] as String?),
      isFavorite: (json['isFavorite'] as int?) == 1,
    );
  }

  static List<String> _parseTags(String? tagsStr) {
    if (tagsStr == null || tagsStr.isEmpty) return [];
    return tagsStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  DiaryEntry copyWith({
    int? id,
    String? content,
    DateTime? createdAt,
    Emotion? mood,
    List<String>? tags,
    bool? isFavorite,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      mood: mood ?? this.mood,
      tags: tags ?? List.from(this.tags),
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  String toString() {
    return 'DiaryEntry(id:$id, ${createdAt.toIso8601String().substring(0, 10)}, '
        '情绪:${mood.label}, 字数:$wordCount, ${isFavorite ? "⭐" : ""})';
  }
}

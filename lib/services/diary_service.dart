import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:petpal/models/diary_entry.dart';
import 'package:petpal/models/emotion.dart';
import 'package:petpal/services/native_bridge.dart';

/// 日记数据存储接口（sqflite 实现由外部注入）
abstract class DiaryDatabase {
  Future<List<DiaryEntry>> getAll();
  Future<DiaryEntry?> getById(int id);
  Future<int> insert(DiaryEntry entry);
  Future<int> update(DiaryEntry entry);
  Future<int> delete(int id);
  Future<List<DiaryEntry>> queryByDate(DateTime date);
  Future<List<DiaryEntry>> queryByDateRange(DateTime start, DateTime end);
  Future<List<DiaryEntry>> queryByMood(Emotion mood);
}

/// 日记服务
///
/// 提供日记的完整业务逻辑：CRUD、查询、情绪分析、导出。
class DiaryService {
  static DiaryService? _instance;
  factory DiaryService() {
    _instance ??= DiaryService._();
    return _instance!;
  }
  DiaryService._();

  final _nativeBridge = NativeBridge();

  // ========== 数据库注入 ==========
  DiaryDatabase? _database;
  void setDatabase(DiaryDatabase db) {
    _database = db;
  }
  DiaryDatabase? get database => _database;

  // ========== 回调 ==========
  /// 日记列表变化回调
  void Function()? onDiaryListChanged;

  // ========== CRUD ==========
  /// 创建日记
  Future<DiaryEntry?> createEntry({
    required String content,
    Emotion mood = Emotion.neutral,
    List<String> tags = const [],
    bool isFavorite = false,
  }) async {
    // 数据验证
    final error = DiaryEntry.validate(content);
    if (error != null) {
      throw ArgumentError(error);
    }

    final entry = DiaryEntry(
      content: content.trim(),
      mood: mood,
      tags: tags,
      isFavorite: isFavorite,
    );

    final db = _database;
    if (db == null) {
      throw StateError('DiaryDatabase 未注入，请先调用 setDatabase()');
    }

    final id = await db.insert(entry);
    final saved = entry.copyWith(id: id);

    onDiaryListChanged?.call();
    return saved;
  }

  /// 更新日记
  Future<void> updateEntry(DiaryEntry entry) async {
    final error = DiaryEntry.validate(entry.content);
    if (error != null) {
      throw ArgumentError(error);
    }

    final db = _database;
    if (db == null) throw StateError('DiaryDatabase 未注入');

    await db.update(entry);
    onDiaryListChanged?.call();
  }

  /// 删除日记
  Future<void> deleteEntry(int id) async {
    final db = _database;
    if (db == null) throw StateError('DiaryDatabase 未注入');

    await db.delete(id);
    onDiaryListChanged?.call();
  }

  /// 获取所有日记（按时间倒序）
  Future<List<DiaryEntry>> getAllEntries() async {
    final db = _database;
    if (db == null) return [];

    final entries = await db.getAll();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// 按 ID 获取单篇日记
  Future<DiaryEntry?> getEntryById(int id) async {
    final db = _database;
    if (db == null) return null;
    return db.getById(id);
  }

  // ========== 查询 ==========
  /// 按日期查询日记
  Future<List<DiaryEntry>> queryByDate(DateTime date) async {
    final db = _database;
    if (db == null) return [];
    return db.queryByDate(date);
  }

  /// 按日期范围查询
  Future<List<DiaryEntry>> queryByDateRange(DateTime start, DateTime end) async {
    final db = _database;
    if (db == null) return [];
    return db.queryByDateRange(start, end);
  }

  /// 按情绪查询
  Future<List<DiaryEntry>> queryByMood(Emotion mood) async {
    final db = _database;
    if (db == null) return [];
    return db.queryByMood(mood);
  }

  /// 按标签查询
  Future<List<DiaryEntry>> queryByTag(String tag) async {
    final all = await getAllEntries();
    return all.where((e) => e.tags.any((t) => t.toLowerCase() == tag.toLowerCase())).toList();
  }

  // ========== 收藏 ==========
  /// 切换收藏状态
  Future<void> toggleFavorite(int id) async {
    final entry = await getEntryById(id);
    if (entry == null) return;

    final updated = entry.copyWith(isFavorite: !entry.isFavorite);
    await updateEntry(updated);
  }

  /// 获取所有收藏日记
  Future<List<DiaryEntry>> getFavorites() async {
    final all = await getAllEntries();
    return all.where((e) => e.isFavorite).toList();
  }

  // ========== 情绪统计 ==========
  /// 获取指定时间段内的情绪分布统计
  Future<Map<Emotion, int>> getMoodStats(DateTime start, DateTime end) async {
    final entries = await queryByDateRange(start, end);
    final stats = <Emotion, int>{};

    for (final entry in entries) {
      stats[entry.mood] = (stats[entry.mood] ?? 0) + 1;
    }

    return stats;
  }

  /// 获取情绪分布（最近 N 天）
  Future<Map<Emotion, int>> getRecentMoodStats(int days) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    return getMoodStats(start, now);
  }

  // ========== 情绪小结（调用本地模型总结） ==========
  /// 生成近期日记的情绪摘要
  ///
  /// 调用本地 LLM 分析最近 N 天的日记，生成情绪小结。
  /// 如果 AI 不可用则返回基于统计的简易摘要。
  Future<String> generateMoodSummary({int days = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final entries = await queryByDateRange(start, now);

    if (entries.isEmpty) {
      return '这段时间还没有写日记哦~ 从今天开始记录吧！';
    }

    // 尝试使用 AI 生成摘要
    try {
      final diaryTexts = entries.map((e) =>
        '[${e.createdAt.toString().substring(0, 10)}] '
        '心情${e.moodEmoji}: ${e.content.substring(0, e.content.length.clamp(0, 200))}'
      ).join('\n');

      final prompt = '''
你是一位温暖的心理分析师，请根据以下最近$days天的日记内容，生成一段简短的情绪小结（80字以内）：
日记内容：
$diaryTexts

请用温暖的口吻总结这段时间的情绪变化，语气像关心你的宠物朋友一样。''';

      final summary = await _nativeBridge.infer(prompt);
      return summary;
    } catch (e) {
      // 回退到统计摘要
      return _generateSimpleSummary(entries);
    }
  }

  /// 基于统计生成简单摘要
  String _generateSimpleSummary(List<DiaryEntry> entries) {
    final moodCount = <Emotion, int>{};
    for (final entry in entries) {
      moodCount[entry.mood] = (moodCount[entry.mood] ?? 0) + 1;
    }

    // 找出最常见的情绪
    final sorted = moodCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topMood = sorted.isNotEmpty ? sorted.first.key : Emotion.neutral;
    final totalDays = entries.map((e) => e.date).toSet().length;

    final buffer = StringBuffer();
    buffer.write('最近$totalDays天里写了${entries.length}篇日记。');
    buffer.write('最常出现的情绪是${topMood.emoji}${topMood.label}');

    if (topMood == Emotion.happy || topMood == Emotion.excited) {
      buffer.write('，看来这段时间过得很不错呢！继续保持哦~');
    } else if (topMood == Emotion.sad || topMood == Emotion.angry) {
      buffer.write('，感觉最近心情不太好呢。没关系，我会一直陪着你的~');
    } else {
      buffer.write('，生活有起有伏，每一天都是珍贵的回忆~');
    }

    return buffer.toString();
  }

  // ========== 导出 ==========
  /// 导出日记为图片（通过回调将 RepaintBoundary key 传给 UI 层截图）
  /// [onExportReady] 截图完成回调，传入图片字节数据
  /// [entries] 要导出的日记列表
  void Function(List<DiaryEntry> entries, void Function(Uint8List imageData) onComplete)?
      onRequestScreenshot;

  /// 触发日记导出
  Future<void> exportAsImage({
    List<DiaryEntry>? entries,
    void Function(Uint8List imageData)? onComplete,
  }) async {
    final targetEntries = entries ?? await getAllEntries();
    if (targetEntries.isEmpty) return;

    if (onRequestScreenshot != null && onComplete != null) {
      onRequestScreenshot!(targetEntries, onComplete);
    }
  }

  // ========== 搜索 ==========
  /// 按关键词搜索日记
  Future<List<DiaryEntry>> search(String keyword) async {
    final all = await getAllEntries();
    final lowerKeyword = keyword.toLowerCase();
    return all.where((e) =>
      e.content.toLowerCase().contains(lowerKeyword) ||
      e.tags.any((t) => t.toLowerCase().contains(lowerKeyword))
    ).toList();
  }
}

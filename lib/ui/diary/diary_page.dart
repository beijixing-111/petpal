import 'package:flutter/material.dart';
import 'package:petpal/services/diary_service.dart';
import 'package:petpal/models/diary_entry.dart';
import 'package:petpal/models/emotion.dart';

/// 情绪日记页面 —— 日记列表（时间倒序）+ 新建入口
///
/// 功能：
/// - 日记卡片：情绪标签、日期、内容预览
/// - 搜索 / 情绪筛选
/// - 与 [DiaryService] 联动
class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final _searchController = TextEditingController();
  final _diaryService = DiaryService();

  /// 当前筛选情绪（null 表示全部）
  Emotion? _filterMood;
  /// 日记列表
  List<DiaryEntry> _entries = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _diaryService.onDiaryListChanged = () => _loadEntries();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载日记列表
  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final db = _diaryService.database;
      if (db != null) {
        final all = await db.getAll();
        // 按时间倒序
        all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (mounted) setState(() => _entries = all);
      }
    } catch (e) {
      debugPrint('加载日记失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 筛选 + 搜索后的日记列表
  List<DiaryEntry> get _filteredEntries {
    var result = List<DiaryEntry>.from(_entries);

    if (_filterMood != null) {
      result = result.where((e) => e.mood == _filterMood).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((e) => e.content.toLowerCase().contains(query)).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching ? _buildSearchField() : const Text('情绪日记'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterMood = null;
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToNewEntry(),
        icon: const Icon(Icons.edit),
        label: const Text('写日记'),
      ),
      body: Column(
        children: [
          // —— 情绪标签筛选栏 ——
          _buildMoodFilterChips(),
          // —— 日记列表 ——
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadEntries,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: entries.length,
                          itemBuilder: (context, index) => _buildDiaryCard(entries[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: const InputDecoration(hintText: '搜索日记...', border: InputBorder.none),
      onChanged: (_) => setState(() {}),
    );
  }

  /// 情绪筛选 Chips
  Widget _buildMoodFilterChips() {
    // 排除纯动画情绪，仅保留主要情绪
    const moods = [
      Emotion.happy,
      Emotion.sad,
      Emotion.excited,
      Emotion.angry,
      Emotion.sleepy,
      Emotion.hungry,
      Emotion.neutral,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _moodChip('全部', null),
          for (final mood in moods) _moodChip('${mood.emoji} ${mood.label}', mood),
        ],
      ),
    );
  }

  Widget _moodChip(String label, Emotion? value) {
    final isSelected = _filterMood == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => setState(() => _filterMood = selected ? value : null),
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  /// 单张日记卡片
  Widget _buildDiaryCard(DiaryEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToSummary(entry.id ?? 0),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 情绪徽章 + 日期
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _moodBadge(entry.mood),
                  Text(
                    _formatDate(entry.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 内容预览
              Text(
                entry.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              // 标签
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: entry.tags
                      .map((t) => Chip(
                            label: Text(t, style: const TextStyle(fontSize: 10)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
              // 收藏星标
              if (entry.isFavorite)
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.star, size: 16, color: Colors.amber),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moodBadge(Emotion mood) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _moodColor(mood).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${mood.emoji} ${mood.label}',
        style: TextStyle(fontSize: 12, color: _moodColor(mood), fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _moodColor(Emotion mood) {
    switch (mood) {
      case Emotion.happy:
        return Colors.amber;
      case Emotion.sad:
        return Colors.blue;
      case Emotion.excited:
        return Colors.pink;
      case Emotion.angry:
        return Colors.red;
      case Emotion.sleepy:
        return Colors.grey;
      case Emotion.hungry:
        return Colors.orange;
      case Emotion.neutral:
      default:
        return Colors.teal;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.book_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('还没有日记，记录今天的心情吧~',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  void _navigateToNewEntry() {
    // TODO: 跳转到新建日记页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('新建日记功能开发中'), duration: Duration(seconds: 1)),
    );
  }

  void _navigateToSummary(int entryId) {
    if (entryId > 0) Navigator.pushNamed(context, '/summary', arguments: entryId);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

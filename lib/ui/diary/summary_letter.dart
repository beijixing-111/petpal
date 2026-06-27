import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart'; // TODO: 添加 share_plus 依赖
import 'package:petpal/services/diary_service.dart';
import 'package:petpal/models/diary_entry.dart';
import 'package:petpal/models/emotion.dart';

/// 情绪小结信页面 —— 精美信纸风格的情绪分析报告
///
/// 支持：
/// - RepaintBoundary 包裹用于截图分享
/// - "保存为图片" / "分享" 按钮
/// - 信纸风格排版（米黄底 + 横线装饰）
class SummaryLetter extends StatefulWidget {
  final int entryId;

  const SummaryLetter({super.key, required this.entryId});

  @override
  State<SummaryLetter> createState() => _SummaryLetterState();
}

class _SummaryLetterState extends State<SummaryLetter> {
  final GlobalKey _repaintKey = GlobalKey();
  final _diaryService = DiaryService();
  DiaryEntry? _entry;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    try {
      final db = _diaryService.database;
      if (db != null) {
        final entry = await db.getById(widget.entryId);
        if (mounted) setState(() { _entry = entry; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('情绪小结信')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('情绪小结信')),
        body: const Center(child: Text('日记不存在')),
      );
    }

    final entry = _entry!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('情绪小结信'),
        actions: [
          IconButton(icon: const Icon(Icons.share), tooltip: '分享', onPressed: _shareLetter),
          IconButton(icon: const Icon(Icons.save_alt), tooltip: '保存为图片', onPressed: _saveAsImage),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: RepaintBoundary(key: _repaintKey, child: _buildLetterPaper(entry)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveAsImage,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('保存为图片'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareLetter,
                  icon: const Icon(Icons.share),
                  label: const Text('分享'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// —— 信纸布局 ——
  Widget _buildLetterPaper(DiaryEntry entry) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLetterHeader(entry),
          const SizedBox(height: 24),
          Divider(color: Colors.brown.shade200, thickness: 0.5),
          const SizedBox(height: 24),
          _buildSectionTitle('📊 情绪分析'),
          const SizedBox(height: 8),
          _buildMoodInfo(entry),
          const SizedBox(height: 24),
          _buildSectionTitle('📝 你的日记'),
          const SizedBox(height: 8),
          Text(entry.content, style: TextStyle(fontSize: 15, height: 1.8, color: Colors.brown.shade800)),
          const SizedBox(height: 24),
          _buildSectionTitle('💌 来自宠物的寄语'),
          const SizedBox(height: 8),
          _buildPetMessage(entry),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text('— PetPal 与你同在 —', style: TextStyle(fontSize: 13, color: Colors.brown.shade400, fontStyle: FontStyle.italic)),
                const SizedBox(height: 4),
                Text('${entry.createdAt.year}.${entry.createdAt.month.toString().padLeft(2, '0')}.${entry.createdAt.day.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11, color: Colors.brown.shade300)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterHeader(DiaryEntry entry) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('亲爱的主人：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${entry.createdAt.year}年${entry.createdAt.month}月${entry.createdAt.day}日',
                style: TextStyle(fontSize: 12, color: Colors.brown.shade500)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _moodColor(entry.mood).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text('${entry.moodEmoji} ${entry.moodLabel}',
              style: TextStyle(fontSize: 14, color: _moodColor(entry.mood), fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.brown.shade700)),
      ],
    );
  }

  Widget _buildMoodInfo(DiaryEntry entry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('情绪', '${entry.moodEmoji} ${entry.moodLabel}'),
          const SizedBox(height: 6),
          _infoRow('字数', '${entry.wordCount} 字'),
          const SizedBox(height: 6),
          _infoRow('标签', entry.tags.isNotEmpty ? entry.tags.join('、') : '—'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 48, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.brown.shade500))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: Colors.brown.shade800))),
      ],
    );
  }

  Widget _buildPetMessage(DiaryEntry entry) {
    // 根据情绪生成宠物寄语
    final message = _generatePetMessage(entry.mood);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.brown),
            child: Center(child: Text(entry.moodEmoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 14, height: 1.6, color: Colors.brown.shade800)),
          ),
        ],
      ),
    );
  }

  String _generatePetMessage(Emotion mood) {
    switch (mood) {
      case Emotion.happy: return '看到主人开心，我也好开心呀！今天也是美好的一天呢~ 💕';
      case Emotion.sad: return '主人不要难过，我一直都在你身边。抱抱~ 🤗';
      case Emotion.excited: return '哇！主人今天一定遇到了很棒的事情！快给我讲讲！✨';
      case Emotion.angry: return '冷静冷静~ 深呼吸，没什么大不了的。我来陪你散散心吧 🍃';
      case Emotion.sleepy: return '主人辛苦了，好好休息一下吧。我会守在你身边的~ 😴';
      case Emotion.hungry: return '主人要记得好好吃饭哦！身体最重要！🍎';
      case Emotion.neutral: return '无论晴天雨天，每一天都值得被记录。今天也辛苦啦~ 🌟';
      default: return '今天也辛苦啦~ 我会一直陪在你身边 💕';
    }
  }

  /// —— 保存为图片 ——
  Future<void> _saveAsImage() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/summary_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(filePath).writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存: $filePath')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }

  /// —— 分享 ——
  Future<void> _shareLetter() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/share_summary.png';
      await File(filePath).writeAsBytes(byteData.buffer.asUint8List());

      // await Share.shareXFiles([XFile(filePath)], text: '我的 PetPal 情绪小结信 — ${_entry?.moodLabel ?? ""}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('分享失败: $e')));
    }
  }

  Color _moodColor(Emotion mood) {
    switch (mood) {
      case Emotion.happy: return Colors.amber;
      case Emotion.sad: return Colors.blue;
      case Emotion.excited: return Colors.pink;
      case Emotion.angry: return Colors.red;
      case Emotion.sleepy: return Colors.grey;
      case Emotion.hungry: return Colors.orange;
      default: return Colors.teal;
    }
  }
}

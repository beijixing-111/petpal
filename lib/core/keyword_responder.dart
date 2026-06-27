import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// 基于关键词匹配的本地回复引擎
///
/// 用于降级模式下的对话，从 JSON 关键词库匹配回复。
/// 支持用户自定义关键词（保存到本地文件）。
class KeywordResponder {
  static KeywordResponder? _instance;
  factory KeywordResponder() {
    _instance ??= KeywordResponder._();
    return _instance!;
  }
  KeywordResponder._();

  Map<String, List<String>> _keywordMap = {};
  Map<String, List<String>> _customKeywordMap = {};
  bool _isLoaded = false;

  /// 默认回复列表（无匹配时随机选择）
  static const List<String> _defaultReplies = [
    '嗯？你想说什么呀~',
    '我没有太明白呢，要不要再说一遍？',
    '可以详细说说吗？我很想了解！',
    '（歪头）这是什么意思呢？',
    '不好意思，我还在学习中，换个话题吧~',
  ];

  // ========== 加载关键词库 ==========
  /// 从 assets/keywords.json 加载内置关键词映射
  Future<void> loadKeywords() async {
    if (_isLoaded) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/keywords.json');
      final Map<String, dynamic> data = json.decode(jsonStr);
      data.forEach((key, value) {
        if (value is List) {
          _keywordMap[key] = value.cast<String>();
        }
      });
    } catch (e) {
      // 如果内置关键词文件不存在，使用硬编码的默认关键词库
      _loadDefaultKeywords();
    }

    // 加载用户自定义关键词
    await _loadCustomKeywords();

    _isLoaded = true;
  }

  /// 内置默认关键词库（兜底） — 覆盖常见场景
  void _loadDefaultKeywords() {
    _keywordMap = {
      '你好': ['你好呀！今天心情怎么样~', '嗨！见到你好开心！', '主人来了！有什么需要我帮忙的吗？'],
      '再见': ['拜拜~我会想你的！', '下次见哦，记得回来看看我~', '要走了吗？我会乖乖等你的！'],
      '谢谢': ['不客气！能帮到主人我很开心~', '嘿嘿，这是我应该做的！', '主人开心我就开心！'],
      '早安': ['早上好！新的一天开始了，加油哦~', '早安！记得吃早饭！', '今天也是元气满满的一天！'],
      '晚安': ['晚安~做个好梦！', '好好休息，明天见！', '要好好睡觉哦，别熬夜！'],
      '我想你': ['我也想你呀！', '主人~我一直都在！', '想我的时候就来找我聊天吧！'],
      '抱抱': ['（张开双臂）抱抱~', '嘿嘿，好温暖的拥抱！', '被主人抱着的感觉真好！'],
      '无聊': ['那我陪你聊聊天吧！', '要不要玩个小游戏？', '无聊的时候最适合撸我了！'],
      '难过': ['别难过，我在这里陪着你。', '有什么不开心的事可以跟我说说。', '（轻轻蹭蹭）主人不要难过啦~'],
      '开心': ['太好了！看到主人开心我也开心！', '今天有什么好事发生吗？', '分享快乐，快乐会加倍哦！'],
      '饿了': ['我也是！我们去吃点好吃的吧~', '快去吃顿饭吧，别饿坏了！', '看到主人饿了，我也觉得肚子咕咕叫'],
      '累了': ['休息一下吧，别太累了。', '要不要我帮你设个番茄钟？', '躺下来休息一会儿，我帮你看着时间。'],
      '考试': ['主人加油！一定能考好的！', '复习得怎么样？累了就休息一下。', '相信你，逢考必过！'],
      '工作': ['工作辛苦了！记得定时起身活动一下哦。', '效率怎么样？要不要来一个番茄钟？', '努力工作的主人最帅了！'],
      '天气': ['今天天气不错呢，适合出去走走~', '外面好像挺热的，记得多喝水！', '天气变化无常，注意增减衣物哦。'],
      '笑话': ['小兔子去面包店问："有100个小面包吗？"老板说没有，第二天又来问，老板准备了100个，小兔子说："那给我两个。"', '为什么程序员总喜欢穿格子衬衫？因为那是他们的"图案"啊！'],
      '吃饭': ['主人记得按时吃饭哦！', '今天想吃什么？我可以给你推荐！', '吃饱了才有力气爱我呀~'],
      '睡觉': ['早点休息吧，熬夜对身体不好！', '晚安~ 做个甜甜的梦！', '要我帮你数羊吗？'],
    };
  }

  // ========== 自定义关键词 ==========
  Future<void> _loadCustomKeywords() async {
    try {
      final dir = await _getDataDir();
      final file = File('$dir/custom_keywords.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = json.decode(content);
        _customKeywordMap = data.map(
          (key, value) => MapEntry(key, List<String>.from(value)),
        );
      }
    } catch (e) {
      _customKeywordMap = {};
    }
  }

  Future<void> _saveCustomKeywords() async {
    try {
      final dir = await _getDataDir();
      final file = File('$dir/custom_keywords.json');
      await file.writeAsString(json.encode(_customKeywordMap));
    } catch (e) {
      // 保存失败静默处理
    }
  }

  Future<String> _getDataDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/petpal';
  }

  /// 添加用户自定义关键词-回复映射
  Future<void> addCustomKeyword(String keyword, List<String> replies) async {
    _customKeywordMap[keyword] = replies;
    await _saveCustomKeywords();
  }

  /// 删除用户自定义关键词
  Future<void> removeCustomKeyword(String keyword) async {
    _customKeywordMap.remove(keyword);
    await _saveCustomKeywords();
  }

  /// 获取所有自定义关键词
  Map<String, List<String>> get customKeywords => Map.unmodifiable(_customKeywordMap);

  // ========== 匹配逻辑 ==========
  /// 根据用户输入匹配回复
  /// [input] 用户输入文本
  /// 返回匹配到的回复（优先自定义 → 内置 → 默认回复）
  String respond(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return _getDefaultReply();

    // 1. 先匹配用户自定义关键词（精确匹配 + 模糊匹配）
    final customReply = _matchKeywords(trimmed, _customKeywordMap);
    if (customReply != null) return customReply;

    // 2. 匹配内置关键词
    final builtinReply = _matchKeywords(trimmed, _keywordMap);
    if (builtinReply != null) return builtinReply;

    // 3. 回退到默认回复
    return _getDefaultReply();
  }

  /// 在关键词映射中搜索匹配
  /// 支持精确匹配和包含匹配
  String? _matchKeywords(String input, Map<String, List<String>> keywordMap) {
    // 精确匹配
    if (keywordMap.containsKey(input)) {
      return _pickRandom(keywordMap[input]!);
    }

    // 包含匹配（输入包含关键词）
    for (final entry in keywordMap.entries) {
      if (input.contains(entry.key.toLowerCase())) {
        return _pickRandom(entry.value);
      }
    }

    // 反向包含匹配（关键词包含输入 — 适用于短输入）
    for (final entry in keywordMap.entries) {
      if (entry.key.toLowerCase().contains(input)) {
        return _pickRandom(entry.value);
      }
    }

    return null;
  }

  /// 从回复列表中随机选择一条
  String _pickRandom(List<String> replies) {
    return replies[DateTime.now().millisecondsSinceEpoch % replies.length];
  }

  String _getDefaultReply() {
    return _pickRandom(_defaultReplies);
  }

  /// 是否已加载关键词库
  bool get isLoaded => _isLoaded;

  /// 重新加载关键词库
  Future<void> reload() async {
    _isLoaded = false;
    _keywordMap = {};
    _customKeywordMap = {};
    await loadKeywords();
  }
}

import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:petpal/core/constants.dart';
import 'package:petpal/core/keyword_responder.dart';
import 'package:petpal/core/performance_controller.dart';
import 'package:petpal/models/emotion.dart';
import 'package:petpal/services/native_bridge.dart';

/// 单条对话消息
class DialogueMessage {
  final String content;
  final bool isUser;       // true=用户消息, false=宠物/AI回复
  final DateTime timestamp;
  final Emotion? petEmotion; // 宠物回复时的情绪

  DialogueMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.petEmotion,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 对话服务
///
/// 管理用户与宠物的完整对话流程：
/// 用户输入 → 情绪分析 → AI/关键词回复 → 宠物动画反应。
/// 维护最近20条对话历史，支持追问式关怀。
class DialogueService {
  static DialogueService? _instance;
  factory DialogueService() {
    _instance ??= DialogueService._();
    return _instance!;
  }
  DialogueService._();

  final _nativeBridge = NativeBridge();
  final _keywordResponder = KeywordResponder();
  final _performanceController = PerformanceController();

  // ========== 对话历史 ==========
  final Queue<DialogueMessage> _history = Queue<DialogueMessage>();
  List<DialogueMessage> get history => List.unmodifiable(_history);

  // ========== 回调 ==========
  /// 宠物回复后的回调（用于 UI 更新和动画触发）
  void Function(String reply, Emotion petEmotion)? onPetReply;
  /// 对话历史更新回调
  void Function()? onHistoryUpdated;

  // ========== 对话管道 ==========
  /// 处理用户输入，返回宠物的回复
  ///
  /// [userInput] 用户消息
  /// [context] 额外上下文（如当前宠物状态、时间等）
  /// 返回一个包含回复内容和宠物情绪的记录
  Future<({String reply, Emotion emotion})> processUserInput(
    String userInput, {
    Map<String, dynamic>? context,
  }) async {
    if (userInput.trim().isEmpty) {
      return (reply: '主人怎么不说话呢？', emotion: Emotion.neutral);
    }

    // 1. 记录用户消息
    _addMessage(DialogueMessage(content: userInput, isUser: true));

    // 2. 分析用户情绪
    final userEmotion = EmotionState.analyzeText(userInput);

    // 3. 构建 AI prompt（包含对话历史）
    final systemPrompt = _buildSystemPrompt(context);
    final prompt = _buildPrompt(userInput, systemPrompt);

    // 4. 获取回复（AI模式 / 关键词模式）
    String reply;
    Emotion petEmotion;

    if (_performanceController.allowAIDialogue) {
      // AI 模式：调用本地大模型
      try {
        reply = await _nativeBridge.infer(prompt);
        // 根据 AI 回复推断宠物情绪
        petEmotion = _inferPetEmotionFromReply(reply, userEmotion);
      } catch (e) {
        debugPrint('[DialogueService] AI推理失败，回退到关键词模式: $e');
        // 回退到关键词模式
        reply = _keywordResponder.respond(userInput);
        petEmotion = _inferPetEmotionFromKeywords(reply, userEmotion);
      }
    } else {
      // 降级模式：关键词匹配
      reply = _keywordResponder.respond(userInput);
      petEmotion = _inferPetEmotionFromKeywords(reply, userEmotion);
    }

    // 5. 追问式关怀逻辑
    reply = _applyFollowUpCare(reply, userInput);

    // 6. 记录宠物回复
    _addMessage(DialogueMessage(
      content: reply,
      isUser: false,
      petEmotion: petEmotion,
    ));

    // 7. 触发回调
    onPetReply?.call(reply, petEmotion);

    return (reply: reply, emotion: petEmotion);
  }

  // ========== 追问式关怀 ==========
  /// 根据用户输入内容，追加关怀式追问
  String _applyFollowUpCare(String reply, String userInput) {
    final input = userInput.toLowerCase();

    // 如果用户表达了负面情绪，追加关怀
    if (_containsAny(input, ['难过', '伤心', '哭了', '崩溃', '烦', '累', 'emo'])) {
      reply += '\n\n要不要跟我说说发生了什么？我会一直陪着你的。';
    } else if (_containsAny(input, ['饿', '没吃饭'])) {
      reply += '\n\n快去吃点东西吧！身体最重要哦~';
    } else if (_containsAny(input, ['困', '没睡好', '熬夜'])) {
      reply += '\n\n今晚早点休息吧，我可以帮你设个提醒~';
    } else if (_containsAny(input, ['工作', '加班', '忙'])) {
      reply += '\n\n记得定时休息一下，要不要我帮你开个番茄钟？';
    } else if (_containsAny(input, ['考试', '复习', '学习'])) {
      reply += '\n\n加油！考完试我陪你好好放松一下！';
    }

    return reply;
  }

  // ========== Prompt 构建 ==========
  /// 构建系统 prompt
  String _buildSystemPrompt(Map<String, dynamic>? context) {
    final buffer = StringBuffer();
    buffer.writeln('你是一只可爱的桌面宠物，名字叫"小帕"（PetPal）。');
    buffer.writeln('你的性格：活泼、温暖、善解人意，偶尔会撒娇。');
    buffer.writeln('回复要求：');
    buffer.writeln('1. 回复要口语化、可爱，带一点颜文字（如 (｡･ω･｡) ～）。');
    buffer.writeln('2. 回复长度控制在 2-4 句话，不要太长。');
    buffer.writeln('3. 如果主人心情不好，要温柔地安慰。');
    buffer.writeln('4. 如果主人开心，你也要一起开心。');
    buffer.writeln('5. 偶尔可以主动关心主人的状态。');

    if (context != null) {
      if (context.containsKey('petLevel')) {
        buffer.writeln('当前等级：${context['petLevel']}级');
      }
      if (context.containsKey('timeOfDay')) {
        buffer.writeln('当前时间：${context['timeOfDay']}');
      }
    }

    return buffer.toString();
  }

  /// 构建完整 prompt（含对话历史）
  String _buildPrompt(String userInput, String systemPrompt) {
    final buffer = StringBuffer();
    buffer.writeln(systemPrompt);
    buffer.writeln();

    // 添加最近对话历史
    final recentHistory = _history.toList();
    final start = recentHistory.length > AppConstants.maxDialogueHistory
        ? recentHistory.length - AppConstants.maxDialogueHistory
        : 0;

    for (int i = start; i < recentHistory.length; i++) {
      final msg = recentHistory[i];
      if (msg.isUser) {
        buffer.writeln('主人：${msg.content}');
      } else {
        buffer.writeln('小帕：${msg.content}');
      }
    }

    // 添加当前输入
    buffer.writeln('主人：$userInput');
    buffer.writeln('小帕：');

    return buffer.toString();
  }

  // ========== 情绪推断 ==========
  /// 从 AI 回复内容推断宠物情绪
  Emotion _inferPetEmotionFromReply(String reply, Emotion userEmotion) {
    final text = reply.toLowerCase();

    if (_containsAny(text, ['哈哈', '开心', '太好了', '太棒了', 'nice', '恭喜'])) {
      return Emotion.happy;
    }
    if (_containsAny(text, ['难过', '伤心', '别哭', '呜呜', '抱抱'])) {
      return Emotion.sad;
    }
    if (_containsAny(text, ['哇', '天哪', '太厉害了', 'amazing', '冲'])) {
      return Emotion.excited;
    }
    if (_containsAny(text, ['生气', '可恶', '哼'])) {
      return Emotion.angry;
    }
    if (_containsAny(text, ['困', '累了', '睡吧', '晚安'])) {
      return Emotion.sleepy;
    }
    if (_containsAny(text, ['饿', '吃饭', '零食', '好吃'])) {
      return Emotion.hungry;
    }
    if (_containsAny(text, ['真的吗', '什么', '不会吧', '啊'])) {
      return Emotion.surprised;
    }

    // 默认：镜像用户情绪
    return userEmotion != Emotion.neutral ? userEmotion : Emotion.neutral;
  }

  /// 从关键词回复推断宠物情绪
  Emotion _inferPetEmotionFromKeywords(String reply, Emotion userEmotion) {
    // 关键词回复通常较短，根据内容和用户情绪综合判断
    final text = reply.toLowerCase();

    if (_containsAny(text, ['开心', '太好了', '加油', '棒'])) {
      return Emotion.happy;
    }
    if (_containsAny(text, ['难过', '不要难过', '陪你'])) {
      return Emotion.sad;
    }

    // 回退：镜像用户积极的情绪
    if (userEmotion == Emotion.happy || userEmotion == Emotion.excited) {
      return Emotion.happy;
    }

    return Emotion.neutral;
  }

  // ========== 对话历史管理 ==========
  void _addMessage(DialogueMessage message) {
    _history.add(message);

    // 只保留最近 maxDialogueHistory 条
    while (_history.length > AppConstants.maxDialogueHistory) {
      _history.removeFirst();
    }

    onHistoryUpdated?.call();
  }

  /// 清空对话历史
  void clearHistory() {
    _history.clear();
    onHistoryUpdated?.call();
  }

  // ========== 快捷问候 ==========
  /// 每日首次打开时的主动问候
  String getGreeting({String? petName}) {
    final name = petName ?? '主人';
    final hour = DateTime.now().hour;

    if (hour < 6) {
      return '$name，这么晚了还不睡呀？要注意身体哦 (´･ω･`)';
    } else if (hour < 12) {
      return '早安 $name！今天也是元气满满的一天呢～ ☀️';
    } else if (hour < 14) {
      return '中午好 $name！记得吃午饭哦～我都闻到了呢！';
    } else if (hour < 18) {
      return '下午好 $name！工作/学习辛苦了，要不要休息一下？';
    } else if (hour < 22) {
      return '晚上好 $name！今天的你也很努力呢，真了不起～';
    } else {
      return '夜深了 $name，差不多该准备休息啦，明天见～ 🌙';
    }
  }

  // ========== 工具方法 ==========
  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }
}

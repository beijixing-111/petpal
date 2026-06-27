import 'dart:math';

/// 宠物情绪枚举
enum Emotion {
  happy,    // 开心
  sad,      // 难过
  excited,  // 兴奋
  angry,    // 生气
  sleepy,   // 困倦
  hungry,   // 饥饿
  neutral,  // 平静

  // 特殊情绪（仅用于动画触发）
  surprised, // 惊讶
  shy,       // 害羞
  proud,     // 得意
}

/// Emotion 扩展：提供中文名和 emoji
extension EmotionExtension on Emotion {
  String get label {
    switch (this) {
      case Emotion.happy:     return '开心';
      case Emotion.sad:       return '难过';
      case Emotion.excited:   return '兴奋';
      case Emotion.angry:     return '生气';
      case Emotion.sleepy:    return '困倦';
      case Emotion.hungry:    return '饿了';
      case Emotion.neutral:   return '平静';
      case Emotion.surprised: return '惊讶';
      case Emotion.shy:       return '害羞';
      case Emotion.proud:     return '得意';
    }
  }

  String get emoji {
    switch (this) {
      case Emotion.happy:     return '😊';
      case Emotion.sad:       return '😢';
      case Emotion.excited:   return '🤩';
      case Emotion.angry:     return '😤';
      case Emotion.sleepy:    return '😴';
      case Emotion.hungry:    return '😋';
      case Emotion.neutral:   return '😐';
      case Emotion.surprised: return '😲';
      case Emotion.shy:       return '😳';
      case Emotion.proud:     return '😎';
    }
  }

  /// 情绪对应的 Live2D 动画名
  String get animationName {
    switch (this) {
      case Emotion.happy:     return 'happy_idle';
      case Emotion.sad:       return 'sad_idle';
      case Emotion.excited:   return 'excited_jump';
      case Emotion.angry:     return 'angry_shake';
      case Emotion.sleepy:    return 'sleep_yawn';
      case Emotion.hungry:    return 'hungry_rub';
      case Emotion.neutral:   return 'neutral_idle';
      case Emotion.surprised: return 'surprised_bounce';
      case Emotion.shy:       return 'shy_cover';
      case Emotion.proud:     return 'proud_pose';
    }
  }

  /// 情绪对应的静态精灵图（降级模式）
  String get spriteName {
    switch (this) {
      case Emotion.happy:     return 'pet_happy';
      case Emotion.sad:       return 'pet_sad';
      case Emotion.excited:   return 'pet_excited';
      case Emotion.angry:     return 'pet_angry';
      case Emotion.sleepy:    return 'pet_sleepy';
      case Emotion.hungry:    return 'pet_hungry';
      case Emotion.neutral:   return 'pet_neutral';
      case Emotion.surprised: return 'pet_surprised';
      case Emotion.shy:       return 'pet_shy';
      case Emotion.proud:     return 'pet_proud';
    }
  }
}

/// 情绪状态 —— 当前情绪 + 强度 + 持续
class EmotionState {
  Emotion current;
  double intensity;     // 情绪强度 0.0-1.0
  DateTime startTime;   // 当前情绪开始时间
  Duration? duration;   // 持续时间（null 表示手动切换前持续）
  Emotion? previous;    // 上一个情绪（用于回到 baseline）

  EmotionState({
    this.current = Emotion.neutral,
    this.intensity = 0.5,
    DateTime? startTime,
    this.duration,
    this.previous,
  }) : startTime = startTime ?? DateTime.now();

  // ========== 计算属性 ==========
  /// 情绪是否已过期（有持续时间且已超时）
  bool get isExpired {
    if (duration == null) return false;
    return DateTime.now().difference(startTime) >= duration!;
  }

  /// 剩余持续时间
  Duration get remaining {
    if (duration == null) return const Duration(hours: 24);
    final elapsed = DateTime.now().difference(startTime);
    final remaining = duration! - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// 情绪强度百分比文本
  String get intensityPercent => '${(intensity * 100).round()}%';

  // ========== 情绪转换逻辑 ==========
  /// 切换到新情绪
  void transitionTo(Emotion newEmotion, {double intensity = 0.7, Duration? duration}) {
    // 相同情绪且强度变化小则不切换
    if (newEmotion == current && (intensity - this.intensity).abs() < 0.2) {
      return;
    }

    previous = current;
    current = newEmotion;
    this.intensity = intensity.clamp(0.0, 1.0);
    startTime = DateTime.now();
    this.duration = duration;
  }

  /// 情绪随时间衰减，回归平静
  void decay({double rate = 0.1}) {
    if (current == Emotion.neutral) return;

    intensity = (intensity - rate).clamp(0.0, 1.0);

    if (intensity <= 0.05) {
      // 强度过低时回到平静
      previous = current;
      current = Emotion.neutral;
      intensity = 0.3;
      startTime = DateTime.now();
      duration = null;
    }
  }

  /// 根据饱食度自动更新情绪
  void updateFromFullness(int fullness) {
    if (fullness <= 20) {
      transitionTo(Emotion.hungry, intensity: 0.8, duration: null);
    } else if (fullness <= 50 && current == Emotion.hungry) {
      // 饱食度恢复，回归平静
      transitionTo(Emotion.neutral, intensity: 0.3);
    }
  }

  /// 根据亲密度自动更新情绪
  void updateFromAffection(int affection) {
    if (affection >= 80 && current != Emotion.happy && current != Emotion.excited) {
      transitionTo(Emotion.happy, intensity: 0.6);
    } else if (affection <= 20 && current != Emotion.sad) {
      transitionTo(Emotion.sad, intensity: 0.5);
    }
  }

  // ========== 用户输入文本情绪分析 ==========
  /// 根据用户输入文本，通过关键词匹配推断情绪
  static Emotion analyzeText(String text) {
    final input = text.toLowerCase().trim();

    // 开心相关关键词
    if (_containsAny(input, ['哈哈', '开心', '太好了', 'nice', '棒', '赞', '喜欢', '爱', '嘻嘻', '嘿嘿', '耶', 'wow', '好耶', '快乐'])) {
      return Emotion.happy;
    }
    // 兴奋相关
    if (_containsAny(input, ['天哪', '不敢置信', '居然', '太棒了', '激动', '牛逼', '厉害', 'amazing', '冲'])) {
      return Emotion.excited;
    }
    // 难过相关
    if (_containsAny(input, ['难过', '伤心', '哭了', '呜呜', '好累', '崩溃', '无奈', '叹气', '唉', '烦', 'emo', '抑郁'])) {
      return Emotion.sad;
    }
    // 生气相关
    if (_containsAny(input, ['气死', '生气', '愤怒', '混蛋', '可恶', '讨厌', '烦死了', 'gun', '滚', '无语', '恶心'])) {
      return Emotion.angry;
    }
    // 惊讶相关
    if (_containsAny(input, ['啊', '什么', '真的吗', '不是吧', '震惊', '居然', '我的天', '哇塞'])) {
      return Emotion.surprised;
    }
    // 害羞相关
    if (_containsAny(input, ['哎呀', '害羞', '不好意思', '脸红', '难为情', '羞羞'])) {
      return Emotion.shy;
    }
    // 得意相关
    if (_containsAny(input, ['看我的', '厉害吧', '我做到了', '才知道', '学会', '搞定', '拿下'])) {
      return Emotion.proud;
    }

    return Emotion.neutral;
  }

  static bool _containsAny(String input, List<String> keywords) {
    return keywords.any((kw) => input.contains(kw));
  }

  // ========== JSON 序列化 ==========
  Map<String, dynamic> toJson() {
    return {
      'current': current.index,
      'intensity': intensity,
      'startTime': startTime.toIso8601String(),
      'durationMs': duration?.inMilliseconds,
      'previous': previous?.index,
    };
  }

  factory EmotionState.fromJson(Map<String, dynamic> json) {
    return EmotionState(
      current: Emotion.values[json['current'] as int? ?? 6],
      intensity: (json['intensity'] as num?)?.toDouble() ?? 0.5,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      previous: json['previous'] != null
          ? Emotion.values[json['previous'] as int]
          : null,
    );
  }

  EmotionState copyWith({
    Emotion? current,
    double? intensity,
    DateTime? startTime,
    Duration? duration,
    Emotion? previous,
  }) {
    return EmotionState(
      current: current ?? this.current,
      intensity: intensity ?? this.intensity,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      previous: previous ?? this.previous,
    );
  }

  @override
  String toString() {
    return 'EmotionState(${current.label} ${current.emoji}, 强度:$intensityPercent)';
  }
}

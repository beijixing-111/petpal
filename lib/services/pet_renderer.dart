import 'dart:ui' show Color;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:petpal/models/emotion.dart';
import 'package:petpal/core/constants.dart';
import 'package:petpal/core/performance_controller.dart';
import 'package:petpal/services/native_bridge.dart';

/// 宠物渲染器
///
/// 负责宠物的视觉渲染，支持 Live2D 动画和高性能模式，
/// 在降级模式下自动切换为静态精灵图。
class PetRenderer {
  static PetRenderer? _instance;
  factory PetRenderer() {
    _instance ??= PetRenderer._();
    return _instance!;
  }
  PetRenderer._();

  final _nativeBridge = NativeBridge();
  final _performanceController = PerformanceController();

  // ========== 状态 ==========
  Emotion _currentEmotion = Emotion.neutral;
  bool _isAnimating = false;
  bool _isVisible = true;
  double _opacity = 1.0;

  /// 当前渲染模式（动态计算）
  bool get isLive2DMode =>
      _performanceController.allowLive2D && _performanceController.isHighMode;

  /// 动画队列管理
  final List<String> _animationQueue = [];
  Timer? _animationLoopTimer;
  bool _isProcessingQueue = false;

  // ========== Getters ==========
  Emotion get currentEmotion => _currentEmotion;
  bool get isAnimating => _isAnimating;
  bool get isVisible => _isVisible;
  double get opacity => _opacity;

  // ========== 生命周期 ==========
  /// 初始化渲染器
  Future<void> initialize() async {
    // 设置默认状态
    await _applyEmotion(_currentEmotion);
    _startIdleLoop();
  }

  /// 清理资源
  void dispose() {
    _animationLoopTimer?.cancel();
    _animationQueue.clear();
    _isProcessingQueue = false;
  }

  // ========== 情绪驱动的动画切换 ==========
  /// 根据情绪切换宠物动作/动画
  Future<void> setEmotion(Emotion emotion) async {
    if (_currentEmotion == emotion && _isAnimating) return;

    _currentEmotion = emotion;

    if (isLive2DMode) {
      // Live2D 模式：播放对应动画
      await _playLive2DAnimation(emotion.animationName);
    }
    // 降级模式：直接显示对应精灵图（UI层根据 spriteName 切换图片）

    // 情绪动画播放完后回到 idle
    _startIdleLoop();
  }

  /// 播放一次 Live2D 动画
  Future<void> _playLive2DAnimation(String animationName) async {
    _isAnimating = true;
    try {
      await _nativeBridge.setLive2DAnimation(animationName);
    } catch (e) {
      debugPrint('[PetRenderer] Live2D 动画播放失败: $e');
    }
    _isAnimating = false;
  }

  // ========== 动画循环管理 ==========
  /// 启动空闲动画循环
  void _startIdleLoop() {
    _animationLoopTimer?.cancel();

    if (!isLive2DMode) return;

    // 每 8-15 秒随机触发一个闲散动作
    _animationLoopTimer = Timer.periodic(
      Duration(seconds: 8 + DateTime.now().millisecondsSinceEpoch % 7),
      (_) {
        _playRandomIdleAnimation();
      },
    );
  }

  /// 播放随机闲散动画
  Future<void> _playRandomIdleAnimation() async {
    if (_isAnimating || !isLive2DMode) return;

    // 根据当前情绪选择随机的闲散动作
    final idleAnimations = _getIdleAnimations(_currentEmotion);
    if (idleAnimations.isEmpty) return;

    final animation = idleAnimations[
      DateTime.now().millisecondsSinceEpoch % idleAnimations.length
    ];

    _isAnimating = true;
    try {
      await _nativeBridge.setLive2DAnimation(animation);
      // 等待动画播放
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      // 静默处理
    }
    _isAnimating = false;
  }

  /// 根据情绪获取闲散动画列表
  List<String> _getIdleAnimations(Emotion emotion) {
    switch (emotion) {
      case Emotion.happy:
        return ['happy_idle', 'happy_bounce', 'happy_wiggle'];
      case Emotion.sad:
        return ['sad_idle', 'sad_sigh', 'sad_look_down'];
      case Emotion.excited:
        return ['excited_idle', 'excited_hop', 'excited_spin'];
      case Emotion.angry:
        return ['angry_idle', 'angry_stomp'];
      case Emotion.sleepy:
        return ['sleepy_idle', 'sleepy_yawn', 'sleepy_stretch'];
      case Emotion.hungry:
        return ['hungry_idle', 'hungry_rub'];
      case Emotion.neutral:
        return ['neutral_idle', 'neutral_blink', 'neutral_tilt', 'neutral_stretch'];
      case Emotion.surprised:
        return ['surprised_idle', 'surprised_look'];
      case Emotion.shy:
        return ['shy_idle', 'shy_peek'];
      case Emotion.proud:
        return ['proud_idle', 'proud_pose'];
    }
  }

  // ========== 特殊动作 ==========
  /// 播放特殊动画（一次性，不改变当前情绪）
  Future<void> playSpecialAnimation(String animationName, {Duration? duration}) async {
    if (!isLive2DMode) return;

    _isAnimating = true;
    try {
      await _nativeBridge.setLive2DAnimation(animationName);
      if (duration != null) {
        await Future.delayed(duration);
      }
    } catch (e) {
      debugPrint('[PetRenderer] 特殊动画播放失败: $e');
    }
    _isAnimating = false;

    // 回到空闲循环
    _startIdleLoop();
  }

  // ========== 渲染模式切换 ==========
  /// 当性能模式切换时刷新渲染
  void onPerformanceModeChanged() {
    if (isLive2DMode) {
      // 切换回 Live2D 模式，重新播放当前情绪动画
      _applyEmotion(_currentEmotion);
      _startIdleLoop();
    } else {
      // 降级模式：停止 Live2D 动画循环
      _animationLoopTimer?.cancel();
    }
  }

  Future<void> _applyEmotion(Emotion emotion) async {
    if (isLive2DMode) {
      await _playLive2DAnimation('${emotion.animationName}_enter');
      await Future.delayed(const Duration(milliseconds: 500));
      await _playLive2DAnimation(emotion.animationName);
    }
  }

  // ========== 显示/隐藏 ==========
  void show() {
    _isVisible = true;
    _startIdleLoop();
  }

  void hide() {
    _isVisible = false;
    _animationLoopTimer?.cancel();
  }

  // ========== 透明度 ==========
  Future<void> setOpacity(double value) async {
    _opacity = value.clamp(0.0, 1.0);
    if (isLive2DMode) {
      await _nativeBridge.setLive2DOpacity(_opacity);
    }
  }

  // ========== 性能模式降级时的精灵图支持 ==========
  /// 获取当前应该显示的精灵图资源名
  String get currentSpriteName => _currentEmotion.spriteName;

  /// 获取当前应该显示的情绪颜色
  Color get currentEmotionColor =>
      AppConstants.emotionColors[_currentEmotion.name] ?? AppConstants.emotionColors['neutral']!;
}

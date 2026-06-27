import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:petpal/models/pet_state.dart';
import 'package:petpal/models/emotion.dart';
import 'package:petpal/core/constants.dart';

/// 宠物主状态提供者
///
/// 管理宠物的成长数据(PetState)和情绪(EmotionState)。
/// 负责初始化加载、自动保存、每日刷新、成长系统逻辑。
class PetProvider extends ChangeNotifier {
  PetState _petState;
  EmotionState _emotionState;

  // 自动保存防抖
  Timer? _autoSaveTimer;
  static const _autoSaveDelay = Duration(seconds: 2);

  // 每日刷新定时器（每小时检查一次）
  Timer? _dailyRefreshTimer;

  // 饱食度自然衰减定时器
  Timer? _fullnessDecayTimer;

  /// sqflite 数据加载回调（外部注入以避免循环依赖）
  Future<PetState?> Function()? onLoadPetState;
  Future<void> Function(PetState)? onSavePetState;
  Future<EmotionState?> Function()? onLoadEmotionState;
  Future<void> Function(EmotionState)? onSaveEmotionState;

  PetProvider()
      : _petState = PetState.defaultPet(),
        _emotionState = EmotionState();

  // ========== Getters ==========
  PetState get petState => _petState;
  EmotionState get emotionState => _emotionState;
  Emotion get currentEmotion => _emotionState.current;
  bool get isMaxLevel => _petState.isMaxLevel;

  // ========== 初始化 ==========
  /// 从 sqflite 加载宠物数据
  Future<void> initialize() async {
    // 加载宠物状态
    if (onLoadPetState != null) {
      final loaded = await onLoadPetState!();
      if (loaded != null) {
        _petState = loaded;
      }
    }

    // 加载情绪状态
    if (onLoadEmotionState != null) {
      final loaded = await onLoadEmotionState!();
      if (loaded != null) {
        _emotionState = loaded;
      }
    }

    // 检查并处理离线期间的饱食度衰减
    _applyOfflineDecay();

    // 初始化自动保存
    _scheduleAutoSave();

    // 启动每日刷新定时器
    _startDailyRefreshTimer();

    // 启动饱食度衰减定时器
    _startFullnessDecayTimer();

    notifyListeners();
  }

  /// 处理离线期间的饱食度自然衰减
  void _applyOfflineDecay() {
    // 此处假设 Provider 维护了上次在线时间戳
    // 实际实现中需要从 SharedPreferences/sqflite 读取 lastOnlineTime
    // 简化实现：每次初始化时衰减1小时
    _petState.decayFullness(1);
    _emotionState.updateFromFullness(_petState.fullness);
  }

  // ========== 成长系统 ==========
  /// 增加经验值（通过互动、对话等触发）
  void addExperience(int amount) {
    final result = _petState.addExp(amount);

    if (result.leveledUp) {
      // 升级时触发兴奋情绪
      _emotionState.transitionTo(
        Emotion.excited,
        intensity: 0.9,
        duration: const Duration(seconds: 5),
      );
      debugPrint('[PetProvider] 🎉 升级！ 当前 Lv.${_petState.level}');
    }

    if (result.evolved) {
      // 进化时触发得意情绪
      _emotionState.transitionTo(
        Emotion.proud,
        intensity: 1.0,
        duration: const Duration(seconds: 8),
      );
      debugPrint('[PetProvider] 🦋 进化！ 当前阶段: ${_petState.evolutionStageName}');
    }

    _scheduleAutoSave();
    notifyListeners();
  }

  /// 喂食
  void feed() {
    _petState.feed();
    // 喂食后情绪恢复
    if (_emotionState.current == Emotion.hungry) {
      _emotionState.transitionTo(Emotion.happy, intensity: 0.6, duration: const Duration(seconds: 3));
    }
    _scheduleAutoSave();
    notifyListeners();
  }

  /// 互动（抚摸、玩耍等）
  void interact() {
    _petState.increaseAffection();
    _petState.addExp(amount: 5); // 互动奖励少量经验

    // 根据亲密度更新情绪
    _emotionState.updateFromAffection(_petState.affection);

    _scheduleAutoSave();
    notifyListeners();
  }

  /// 触发特定情绪反应
  void triggerEmotion(Emotion emotion, {double intensity = 0.7, Duration? duration}) {
    _emotionState.transitionTo(emotion, intensity: intensity, duration: duration);
    _scheduleAutoSave();
    notifyListeners();
  }

  // ========== 每日金币 ==========
  /// 尝试领取每日金币
  int tryClaimDailyGold() {
    final claimed = _petState.claimDailyGold();
    if (claimed > 0) {
      _scheduleAutoSave();
      notifyListeners();
    }
    return claimed;
  }

  // ========== 金币相关操作 ==========
  bool spendGold(int amount) {
    final success = _petState.spendGold(amount);
    if (success) {
      _scheduleAutoSave();
      notifyListeners();
    }
    return success;
  }

  void addGold(int amount) {
    _petState.addGold(amount);
    _scheduleAutoSave();
    notifyListeners();
  }

  // ========== 装扮 ==========
  void equipAccessory(String accessoryId) {
    _petState.setAccessory(accessoryId);
    _scheduleAutoSave();
    notifyListeners();
  }

  void removeAccessory() {
    _petState.removeAccessory();
    _scheduleAutoSave();
    notifyListeners();
  }

  // ========== 自动保存 ==========
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, () {
      _autoSave();
    });
  }

  Future<void> _autoSave() async {
    if (onSavePetState != null) {
      await onSavePetState!(_petState);
    }
    if (onSaveEmotionState != null) {
      await onSaveEmotionState!(_emotionState);
    }
  }

  // ========== 定时器 ==========
  void _startDailyRefreshTimer() {
    _dailyRefreshTimer = Timer.periodic(const Duration(hours: 1), (_) {
      // 定时检查是否需要情绪衰减
      _emotionState.decay();
      _emotionState.updateFromFullness(_petState.fullness);

      // 可能触发通知（每日刷新）
      if (_petState.canClaimDailyGold) {
        // 通知UI层可以领取每日金币
      }

      notifyListeners();
    });
  }

  void _startFullnessDecayTimer() {
    // 每小时衰减一次饱食度
    _fullnessDecayTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _petState.decayFullness(1);
      _emotionState.updateFromFullness(_petState.fullness);
      _scheduleAutoSave();
      notifyListeners();
    });
  }

  // ========== 手动保存 ==========
  Future<void> saveNow() async {
    _autoSaveTimer?.cancel();
    await _autoSave();
  }

  // ========== 重置 ==========
  void reset() {
    _petState = PetState.defaultPet();
    _emotionState = EmotionState();
    _scheduleAutoSave();
    notifyListeners();
  }

  // ========== 清理 ==========
  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _dailyRefreshTimer?.cancel();
    _fullnessDecayTimer?.cancel();
    saveNow(); // 最后保存一次
    super.dispose();
  }
}

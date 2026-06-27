import 'package:flutter/material.dart';

/// PetPal 全局常量配置
class AppConstants {
  AppConstants._();

  // ========== MethodChannel 名称 ==========
  static const String channelLlama = 'com.petpal/llama';
  static const String channelPerformance = 'com.petpal/performance';
  static const String channelPip = 'com.petpal/pip';
  static const String channelOverlay = 'com.petpal/overlay';
  static const String channelLive2D = 'com.petpal/live2d';
  static const String channelNotification = 'com.petpal/notification';
  static const String channelBattery = 'com.petpal/battery';
  static const String channelModelDownload = 'com.petpal/model_download';

  // ========== 宠物默认状态值 ==========
  static const int defaultExp = 0;
  static const int defaultLevel = 1;
  static const int defaultFullness = 80;         // 饱食度 0-100
  static const int defaultAffection = 50;         // 亲密度 0-100
  static const int defaultGold = 100;
  static const String defaultAccessory = '';      // 无装扮
  static const int defaultEvolutionStage = 0;     // 初始形态

  // ========== 成长系统常量 ==========
  static const int maxLevel = 50;
  static const int baseExpToLevel = 100;          // 升到2级所需经验
  static const double expCurveGrowth = 1.5;       // 经验曲线增长系数
  static const int dailyGoldAmount = 50;          // 每日签到金币
  static const int feedFullnessRecovery = 20;     // 喂食恢复饱食度
  static const int affectionPerInteraction = 2;   // 每次互动增加亲密度
  static const int maxFullness = 100;
  static const int maxAffection = 100;
  static const int fullnessDecayPerHour = 2;      // 每小时饱食度自然下降

  // ========== 进化阶段 ==========
  static const Map<int, String> evolutionStageNames = {
    0: '幼年期',
    1: '成长期',
    2: '成熟期',
    3: '完全体',
  };
  static const Map<int, int> evolutionLevelRequired = {
    1: 5,
    2: 15,
    3: 30,
  };

  // ========== 颜色常量 ==========
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFFFF6584);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color darkBackgroundColor = Color(0xFF1A1A2E);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color darkCardColor = Color(0xFF2D2D44);
  static const Color goldColor = Color(0xFFFFD700);
  static const Color expBarColor = Color(0xFF4CAF50);
  static const Color fullnessBarColor = Color(0xFFFF9800);
  static const Color affectionBarColor = Color(0xFFE91E63);

  // ========== 情绪颜色映射 ==========
  static const Map<String, Color> emotionColors = {
    'happy': Color(0xFFFFD700),
    'sad': Color(0xFF64B5F6),
    'excited': Color(0xFFFF7043),
    'angry': Color(0xFFEF5350),
    'sleepy': Color(0xFFB39DDB),
    'hungry': Color(0xFFFFA726),
    'neutral': Color(0xFF90A4AE),
  };

  // ========== 尺寸常量 ==========
  static const double petDefaultSize = 200.0;
  static const double petMinSize = 100.0;
  static const double petMaxSize = 400.0;
  static const double petBubbleSize = 150.0;
  static const double bottomNavHeight = 60.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double borderRadius = 12.0;

  // ========== 对话常量 ==========
  static const int maxDialogueHistory = 20;
  static const int maxDiarySummaryDays = 7;
  static const String defaultModelName = 'llama-3.2-3b';
  static const double aiTemperature = 0.7;
  static const int maxContextTokens = 4096;

  // ========== 提醒常量 ==========
  static const int defaultPomodoroMinutes = 25;
  static const int defaultShortBreakMinutes = 5;
  static const int defaultLongBreakMinutes = 15;
  static const int defaultWaterIntervalMinutes = 60;
  static const int defaultSedentaryIntervalMinutes = 45;

  // ========== 性能模式 ==========
  static const String performanceModeHigh = 'high';
  static const String performanceModeDegraded = 'degraded';
  static const double batteryLowThreshold = 0.2;   // 电量低于20%触发降级
  static const double temperatureHighThreshold = 40.0; // 温度超过40°C触发降级

  // ========== 经验曲线计算 ==========
  /// 计算升到指定等级所需的总经验
  static int expToLevel(int level) {
    if (level <= 1) return 0;
    return (baseExpToLevel * (level - 1) * expCurveGrowth).round();
  }

  /// 根据经验值计算当前等级
  static int levelFromExp(int exp) {
    int level = 1;
    while (level < maxLevel && exp >= expToLevel(level + 1)) {
      level++;
    }
    return level;
  }
}

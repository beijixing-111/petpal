import 'package:petpal/core/constants.dart';

/// 宠物核心状态数据类
///
/// 包含宠物的所有成长数据：经验值、等级、饱食度、亲密度、金币等。
/// 支持 toJson/fromJson 用于 sqflite 持久化。
class PetState {
  int exp;
  int level;
  int fullness;      // 0-100 饱食度
  int affection;     // 0-100 亲密度
  int gold;
  String accessory;  // 当前装扮ID，空字符串表示无装扮
  int evolutionStage; // 0-幼年 1-成长 2-成熟 3-完全体
  DateTime lastDailyClaim; // 上次领取每日金币时间

  PetState({
    this.exp = AppConstants.defaultExp,
    this.level = AppConstants.defaultLevel,
    this.fullness = AppConstants.defaultFullness,
    this.affection = AppConstants.defaultAffection,
    this.gold = AppConstants.defaultGold,
    this.accessory = AppConstants.defaultAccessory,
    this.evolutionStage = AppConstants.defaultEvolutionStage,
    DateTime? lastDailyClaim,
  }) : lastDailyClaim = lastDailyClaim ?? DateTime(2000);

  // ========== 计算属性 ==========
  /// 当前等级升级所需经验
  int get expToNextLevel => AppConstants.expToLevel(level + 1);
  /// 升级进度 (0.0-1.0)
  double get levelProgress {
    final currentLevelExp = AppConstants.expToLevel(level);
    final nextLevelExp = AppConstants.expToLevel(level + 1);
    final progress = (exp - currentLevelExp) / (nextLevelExp - currentLevelExp);
    return progress.clamp(0.0, 1.0);
  }
  /// 饱食度进度
  double get fullnessProgress => (fullness / AppConstants.maxFullness).clamp(0.0, 1.0);
  /// 亲密度进度
  double get affectionProgress => (affection / AppConstants.maxAffection).clamp(0.0, 1.0);
  /// 进化阶段名称
  String get evolutionStageName => AppConstants.evolutionStageNames[evolutionStage] ?? '未知';
  /// 是否已满级
  bool get isMaxLevel => level >= AppConstants.maxLevel;
  /// 饱食度是否过低
  bool get isHungry => fullness <= 30;
  /// 是否已到最大进化阶段
  bool get isMaxEvolution => evolutionStage >= 3;

  // ========== 成长方法 ==========
  /// 增加经验值，自动处理升级与进化
  /// 返回本次获得的经验值和是否升级
  ({int gainedExp, bool leveledUp, bool evolved}) addExp(int amount) {
    final oldLevel = level;
    exp += amount;

    // 重新计算等级
    level = AppConstants.levelFromExp(exp);
    final leveledUp = level > oldLevel;

    // 检查进化
    bool evolved = false;
    for (final entry in AppConstants.evolutionLevelRequired.entries) {
      if (level >= entry.value && evolutionStage < entry.key) {
        evolutionStage = entry.key;
        evolved = true;
      }
    }

    return (gainedExp: amount, leveledUp: leveledUp, evolved: evolved);
  }

  /// 喂食：恢复饱食度
  void feed({int amount = AppConstants.feedFullnessRecovery}) {
    fullness = (fullness + amount).clamp(0, AppConstants.maxFullness);
  }

  /// 增加亲密度
  void increaseAffection({int amount = AppConstants.affectionPerInteraction}) {
    affection = (affection + amount).clamp(0, AppConstants.maxAffection);
  }

  /// 消耗饱食度（随时间自然下降）
  void decayFullness(int hours) {
    fullness = (fullness - hours * AppConstants.fullnessDecayPerHour).clamp(0, AppConstants.maxFullness);
  }

  /// 增加金币
  void addGold(int amount) {
    gold += amount;
  }

  /// 消费金币
  bool spendGold(int amount) {
    if (gold >= amount) {
      gold -= amount;
      return true;
    }
    return false;
  }

  /// 设置装扮
  void setAccessory(String accessoryId) {
    accessory = accessoryId;
  }

  /// 移除装扮
  void removeAccessory() {
    accessory = '';
  }

  // ========== 每日金币刷新 ==========
  /// 检查并领取每日金币
  /// 返回领取的金币数量（如果当天已领取则返回0）
  int claimDailyGold() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastDailyClaim.isBefore(today)) {
      gold += AppConstants.dailyGoldAmount;
      lastDailyClaim = now;
      return AppConstants.dailyGoldAmount;
    }
    return 0;
  }

  /// 今天是否已领取每日金币
  bool get canClaimDailyGold {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return lastDailyClaim.isBefore(today);
  }

  // ========== JSON 序列化（sqflite 存取） ==========
  Map<String, dynamic> toJson() {
    return {
      'exp': exp,
      'level': level,
      'fullness': fullness,
      'affection': affection,
      'gold': gold,
      'accessory': accessory,
      'evolutionStage': evolutionStage,
      'lastDailyClaim': lastDailyClaim.toIso8601String(),
    };
  }

  factory PetState.fromJson(Map<String, dynamic> json) {
    return PetState(
      exp: json['exp'] as int? ?? AppConstants.defaultExp,
      level: json['level'] as int? ?? AppConstants.defaultLevel,
      fullness: json['fullness'] as int? ?? AppConstants.defaultFullness,
      affection: json['affection'] as int? ?? AppConstants.defaultAffection,
      gold: json['gold'] as int? ?? AppConstants.defaultGold,
      accessory: json['accessory'] as String? ?? AppConstants.defaultAccessory,
      evolutionStage: json['evolutionStage'] as int? ?? AppConstants.defaultEvolutionStage,
      lastDailyClaim: json['lastDailyClaim'] != null
          ? DateTime.tryParse(json['lastDailyClaim'] as String) ?? DateTime(2000)
          : DateTime(2000),
    );
  }

  /// 创建默认初始状态的宠物
  factory PetState.defaultPet() {
    return PetState(
      exp: AppConstants.defaultExp,
      level: AppConstants.defaultLevel,
      fullness: AppConstants.defaultFullness,
      affection: AppConstants.defaultAffection,
      gold: AppConstants.defaultGold,
      accessory: AppConstants.defaultAccessory,
      evolutionStage: AppConstants.defaultEvolutionStage,
    );
  }

  PetState copyWith({
    int? exp,
    int? level,
    int? fullness,
    int? affection,
    int? gold,
    String? accessory,
    int? evolutionStage,
    DateTime? lastDailyClaim,
  }) {
    return PetState(
      exp: exp ?? this.exp,
      level: level ?? this.level,
      fullness: fullness ?? this.fullness,
      affection: affection ?? this.affection,
      gold: gold ?? this.gold,
      accessory: accessory ?? this.accessory,
      evolutionStage: evolutionStage ?? this.evolutionStage,
      lastDailyClaim: lastDailyClaim ?? this.lastDailyClaim,
    );
  }

  @override
  String toString() {
    return 'PetState(Lv.$level, EXP:$exp/$expToNextLevel, '
        '饱食度:$fullness, 亲密度:$affection, 金币:$gold, 进化:${evolutionStageName})';
  }
}

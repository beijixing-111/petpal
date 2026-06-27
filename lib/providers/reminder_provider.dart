import 'package:petpal/models/emotion.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:petpal/core/constants.dart';

/// 提醒类型
enum ReminderType {
  pomodoro,    // 番茄钟
  water,       // 喝水
  sedentary,   // 久坐
  custom,      // 自定义
}

/// 提醒类型扩展
extension ReminderTypeExtension on ReminderType {
  String get label {
    switch (this) {
      case ReminderType.pomodoro:   return '番茄钟';
      case ReminderType.water:      return '喝水';
      case ReminderType.sedentary:  return '久坐起身';
      case ReminderType.custom:     return '自定义';
    }
  }

  String get emoji {
    switch (this) {
      case ReminderType.pomodoro:   return '🍅';
      case ReminderType.water:      return '💧';
      case ReminderType.sedentary:  return '🧘';
      case ReminderType.custom:     return '⏰';
    }
  }
}

/// 单条提醒配置
class ReminderConfig {
  final String id;
  final ReminderType type;
  final String title;
  final String body;
  final int intervalMinutes;   // 提醒间隔（分钟）
  bool enabled;

  ReminderConfig({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.intervalMinutes,
    this.enabled = true,
  });
}

/// 提醒提供者
///
/// 管理番茄钟、喝水、久坐等提醒。
/// 通过本地通知触发提醒，宠物会在提醒时做出反应。
class ReminderProvider extends ChangeNotifier {
  // ========== 内置提醒配置 ==========
  final List<ReminderConfig> _builtinReminders = [];

  // ========== 自定义提醒 ==========
  final List<ReminderConfig> _customReminders = [];

  // ========== 当前状态 ==========
  ReminderType? _activePomodoro;          // 当前活跃的番茄钟
  int _pomodoroSecondsRemaining = 0;       // 番茄钟剩余秒数
  bool _isPomodoroBreak = false;           // 是否处于休息阶段
  Timer? _pomodoroTimer;
  DateTime? _lastWaterReminder;
  DateTime? _lastSedentaryReminder;

  // ========== 通知触发回调（外部注入） ==========
  void Function(String title, String body)? onShowNotification;

  // ========== Getters ==========
  List<ReminderConfig> get allReminders => [
    ..._builtinReminders,
    ..._customReminders,
  ];

  List<ReminderConfig> get enabledReminders =>
      allReminders.where((r) => r.enabled).toList();

  ReminderType? get activePomodoro => _activePomodoro;
  int get pomodoroSecondsRemaining => _pomodoroSecondsRemaining;
  bool get isPomodoroBreak => _isPomodoroBreak;
  bool get isPomodoroRunning => _activePomodoro != null;

  /// 格式化番茄钟剩余时间
  String get pomodoroFormatted {
    final minutes = _pomodoroSecondsRemaining ~/ 60;
    final seconds = _pomodoroSecondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ========== 初始化 ==========
  ReminderProvider() {
    _initBuiltinReminders();
  }

  void _initBuiltinReminders() {
    _builtinReminders.clear();
    _builtinReminders.addAll([
      ReminderConfig(
        id: 'pomodoro_work',
        type: ReminderType.pomodoro,
        title: '🍅 番茄钟',
        body: '专注时间到！我陪你一起努力~',
        intervalMinutes: AppConstants.defaultPomodoroMinutes,
        enabled: true,
      ),
      ReminderConfig(
        id: 'pomodoro_short_break',
        type: ReminderType.pomodoro,
        title: '☕ 小休息',
        body: '休息一下，来摸摸我吧！',
        intervalMinutes: AppConstants.defaultShortBreakMinutes,
        enabled: true,
      ),
      ReminderConfig(
        id: 'water',
        type: ReminderType.water,
        title: '💧 喝水提醒',
        body: '主人，该喝水啦！我帮你倒好了~',
        intervalMinutes: AppConstants.defaultWaterIntervalMinutes,
        enabled: true,
      ),
      ReminderConfig(
        id: 'sedentary',
        type: ReminderType.sedentary,
        title: '🧘 起来动动',
        body: '已经坐了很久了，起来活动一下吧！',
        intervalMinutes: AppConstants.defaultSedentaryIntervalMinutes,
        enabled: true,
      ),
    ]);
  }

  // ========== 番茄钟 ==========
  /// 开始番茄钟
  void startPomodoro() {
    _activePomodoro = ReminderType.pomodoro;
    _isPomodoroBreak = false;
    _pomodoroSecondsRemaining = AppConstants.defaultPomodoroMinutes * 60;
    _startPomodoroCountdown();
    notifyListeners();
  }

  /// 开始短休息
  void startShortBreak() {
    _activePomodoro = null; // 番茄钟完成
    _isPomodoroBreak = true;
    _pomodoroSecondsRemaining = AppConstants.defaultShortBreakMinutes * 60;
    _startPomodoroCountdown();
    notifyListeners();
  }

  void _startPomodoroCountdown() {
    _pomodoroTimer?.cancel();
    _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_pomodoroSecondsRemaining > 0) {
        _pomodoroSecondsRemaining--;
        notifyListeners();
      } else {
        _onPomodoroComplete();
      }
    });
  }

  void _onPomodoroComplete() {
    _pomodoroTimer?.cancel();

    if (_isPomodoroBreak) {
      // 休息结束
      _activePomodoro = null;
      _isPomodoroBreak = false;
      onShowNotification?.call('休息结束', '休息好了吗？要继续加油哦！');
    } else {
      // 番茄钟结束，触发通知
      onShowNotification?.call('🍅 番茄钟完成', '太棒了！专注了一整个番茄钟，休息一下吧~');
    }
    notifyListeners();
  }

  /// 停止番茄钟
  void stopPomodoro() {
    _pomodoroTimer?.cancel();
    _activePomodoro = null;
    _isPomodoroBreak = false;
    _pomodoroSecondsRemaining = 0;
    notifyListeners();
  }

  // ========== 提醒管理 ==========
  /// 切换提醒启用状态
  void toggleReminder(String reminderId) {
    for (final reminder in allReminders) {
      if (reminder.id == reminderId) {
        reminder.enabled = !reminder.enabled;
        notifyListeners();
        return;
      }
    }
  }

  /// 添加自定义提醒
  void addCustomReminder(ReminderConfig reminder) {
    _customReminders.add(reminder);
    notifyListeners();
  }

  /// 删除自定义提醒
  void removeCustomReminder(String reminderId) {
    _customReminders.removeWhere((r) => r.id == reminderId);
    notifyListeners();
  }

  /// 更新提醒配置
  void updateReminder(String reminderId, {int? intervalMinutes, bool? enabled}) {
    for (final reminder in allReminders) {
      if (reminder.id == reminderId) {
        if (intervalMinutes != null) {
          (reminder as dynamic).intervalMinutes = intervalMinutes;
        }
        if (enabled != null) {
          reminder.enabled = enabled;
        }
        notifyListeners();
        return;
      }
    }
  }

  // ========== 触发检查（由外部定时器调用） ==========
  /// 检查是否需要发出喝水提醒
  bool checkWaterReminder() {
    final now = DateTime.now();
    if (_lastWaterReminder != null) {
      final diff = now.difference(_lastWaterReminder!).inMinutes;
      final config = _builtinReminders.firstWhere((r) => r.id == 'water');
      if (config.enabled && diff >= config.intervalMinutes) {
        _lastWaterReminder = now;
        onShowNotification?.call(config.title, config.body);
        return true;
      }
    } else {
      _lastWaterReminder = now;
    }
    return false;
  }

  /// 检查是否需要发出久坐提醒
  bool checkSedentaryReminder() {
    final now = DateTime.now();
    if (_lastSedentaryReminder != null) {
      final diff = now.difference(_lastSedentaryReminder!).inMinutes;
      final config = _builtinReminders.firstWhere((r) => r.id == 'sedentary');
      if (config.enabled && diff >= config.intervalMinutes) {
        _lastSedentaryReminder = now;
        onShowNotification?.call(config.title, config.body);
        return true;
      }
    } else {
      _lastSedentaryReminder = now;
    }
    return false;
  }

  // ========== 触发提醒（宠物反应） ==========
  /// 当提醒触发时，返回宠物应该表现的情绪
  Emotion get reminderPetEmotion {
    if (_activePomodoro != null && !_isPomodoroBreak) {
      return Emotion.proud; // 专注中，得意
    }
    return Emotion.neutral;
  }

  // ========== 清理 ==========
  @override
  void dispose() {
    _pomodoroTimer?.cancel();
    super.dispose();
  }
}
// 占位修复（实际应加到文件顶部 import）

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petpal/core/constants.dart';

/// 用户设置提供者
///
/// 管理所有用户偏好设置，通过 SharedPreferences 持久化。
/// 支持：AI对话、提醒开关、音量、主题、字体大小等。
class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  // ========== 设置项 ==========
  bool _aiDialogueEnabled = true;       // 是否启用AI对话
  bool _reminderEnabled = true;          // 是否启用提醒
  bool _pomodoroEnabled = true;          // 番茄钟
  bool _waterReminderEnabled = true;     // 喝水提醒
  bool _sedentaryReminderEnabled = true; // 久坐提醒
  double _volume = 0.7;                 // 音量 0.0-1.0
  bool _darkMode = false;               // 深色模式
  bool _useSystemTheme = true;          // 跟随系统主题
  String _petSize = 'medium';           // 宠物大小: small/medium/large
  bool _showBubble = true;              // 显示对话气泡
  bool _autoStartOnBoot = false;        // 开机自启
  bool _pipEnabled = true;              // PiP画中画
  bool _overlayEnabled = true;          // 桌面悬浮窗
  double _petOpacity = 1.0;            // 宠物透明度
  bool _firstLaunch = true;             // 首次启动标记

  // ========== Getters ==========
  bool get aiDialogueEnabled => _aiDialogueEnabled;
  bool get reminderEnabled => _reminderEnabled;
  bool get pomodoroEnabled => _pomodoroEnabled;
  bool get waterReminderEnabled => _waterReminderEnabled;
  bool get sedentaryReminderEnabled => _sedentaryReminderEnabled;
  double get volume => _volume;
  bool get darkMode => _darkMode;
  bool get useSystemTheme => _useSystemTheme;
  String get petSize => _petSize;
  bool get showBubble => _showBubble;
  bool get autoStartOnBoot => _autoStartOnBoot;
  bool get pipEnabled => _pipEnabled;
  bool get overlayEnabled => _overlayEnabled;
  double get petOpacity => _petOpacity;
  bool get firstLaunch => _firstLaunch;

  // 宠物实际尺寸像素值
  double get petSizePixels {
    switch (_petSize) {
      case 'small':  return AppConstants.petMinSize;
      case 'large':  return AppConstants.petMaxSize;
      default:       return AppConstants.petDefaultSize; // medium
    }
  }

  // ========== 初始化 ==========
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    notifyListeners();
  }

  void _loadSettings() {
    _aiDialogueEnabled = _prefs?.getBool('ai_dialogue_enabled') ?? true;
    _reminderEnabled = _prefs?.getBool('reminder_enabled') ?? true;
    _pomodoroEnabled = _prefs?.getBool('pomodoro_enabled') ?? true;
    _waterReminderEnabled = _prefs?.getBool('water_reminder_enabled') ?? true;
    _sedentaryReminderEnabled = _prefs?.getBool('sedentary_reminder_enabled') ?? true;
    _volume = _prefs?.getDouble('volume') ?? 0.7;
    _darkMode = _prefs?.getBool('dark_mode') ?? false;
    _useSystemTheme = _prefs?.getBool('use_system_theme') ?? true;
    _petSize = _prefs?.getString('pet_size') ?? 'medium';
    _showBubble = _prefs?.getBool('show_bubble') ?? true;
    _autoStartOnBoot = _prefs?.getBool('auto_start_on_boot') ?? false;
    _pipEnabled = _prefs?.getBool('pip_enabled') ?? true;
    _overlayEnabled = _prefs?.getBool('overlay_enabled') ?? true;
    _petOpacity = _prefs?.getDouble('pet_opacity') ?? 1.0;
    _firstLaunch = _prefs?.getBool('first_launch') ?? true;
  }

  // ========== Setters (每个 setter 自动持久化) ==========
  Future<void> setAiDialogueEnabled(bool value) async {
    _aiDialogueEnabled = value;
    await _prefs?.setBool('ai_dialogue_enabled', value);
    notifyListeners();
  }

  Future<void> setReminderEnabled(bool value) async {
    _reminderEnabled = value;
    await _prefs?.setBool('reminder_enabled', value);
    notifyListeners();
  }

  Future<void> setPomodoroEnabled(bool value) async {
    _pomodoroEnabled = value;
    await _prefs?.setBool('pomodoro_enabled', value);
    notifyListeners();
  }

  Future<void> setWaterReminderEnabled(bool value) async {
    _waterReminderEnabled = value;
    await _prefs?.setBool('water_reminder_enabled', value);
    notifyListeners();
  }

  Future<void> setSedentaryReminderEnabled(bool value) async {
    _sedentaryReminderEnabled = value;
    await _prefs?.setBool('sedentary_reminder_enabled', value);
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _prefs?.setDouble('volume', _volume);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _prefs?.setBool('dark_mode', value);
    notifyListeners();
  }

  Future<void> setUseSystemTheme(bool value) async {
    _useSystemTheme = value;
    await _prefs?.setBool('use_system_theme', value);
    notifyListeners();
  }

  Future<void> setPetSize(String value) async {
    if (!['small', 'medium', 'large'].contains(value)) return;
    _petSize = value;
    await _prefs?.setString('pet_size', value);
    notifyListeners();
  }

  Future<void> setShowBubble(bool value) async {
    _showBubble = value;
    await _prefs?.setBool('show_bubble', value);
    notifyListeners();
  }

  Future<void> setAutoStartOnBoot(bool value) async {
    _autoStartOnBoot = value;
    await _prefs?.setBool('auto_start_on_boot', value);
    notifyListeners();
  }

  Future<void> setPipEnabled(bool value) async {
    _pipEnabled = value;
    await _prefs?.setBool('pip_enabled', value);
    notifyListeners();
  }

  Future<void> setOverlayEnabled(bool value) async {
    _overlayEnabled = value;
    await _prefs?.setBool('overlay_enabled', value);
    notifyListeners();
  }

  Future<void> setPetOpacity(double value) async {
    _petOpacity = value.clamp(0.2, 1.0);
    await _prefs?.setDouble('pet_opacity', _petOpacity);
    notifyListeners();
  }

  /// 标记首次启动完成
  Future<void> completeFirstLaunch() async {
    _firstLaunch = false;
    await _prefs?.setBool('first_launch', false);
    notifyListeners();
  }

  // ========== 批量设置（用于数据迁移） ==========
  Future<void> resetToDefaults() async {
    _aiDialogueEnabled = true;
    _reminderEnabled = true;
    _pomodoroEnabled = true;
    _waterReminderEnabled = true;
    _sedentaryReminderEnabled = true;
    _volume = 0.7;
    _darkMode = false;
    _useSystemTheme = true;
    _petSize = 'medium';
    _showBubble = true;
    _autoStartOnBoot = false;
    _pipEnabled = true;
    _overlayEnabled = true;
    _petOpacity = 1.0;

    await _prefs?.clear();
    await _saveAll();
    notifyListeners();
  }

  Future<void> _saveAll() async {
    final p = _prefs;
    if (p == null) return;
    await Future.wait([
      p.setBool('ai_dialogue_enabled', _aiDialogueEnabled),
      p.setBool('reminder_enabled', _reminderEnabled),
      p.setBool('pomodoro_enabled', _pomodoroEnabled),
      p.setBool('water_reminder_enabled', _waterReminderEnabled),
      p.setBool('sedentary_reminder_enabled', _sedentaryReminderEnabled),
      p.setDouble('volume', _volume),
      p.setBool('dark_mode', _darkMode),
      p.setBool('use_system_theme', _useSystemTheme),
      p.setString('pet_size', _petSize),
      p.setBool('show_bubble', _showBubble),
      p.setBool('auto_start_on_boot', _autoStartOnBoot),
      p.setBool('pip_enabled', _pipEnabled),
      p.setBool('overlay_enabled', _overlayEnabled),
      p.setDouble('pet_opacity', _petOpacity),
      p.setBool('first_launch', _firstLaunch),
    ]);
  }

  /// 将所有设置导出为 Map（用于调试/备份）
  Map<String, dynamic> toJson() {
    return {
      'aiDialogueEnabled': _aiDialogueEnabled,
      'reminderEnabled': _reminderEnabled,
      'pomodoroEnabled': _pomodoroEnabled,
      'waterReminderEnabled': _waterReminderEnabled,
      'sedentaryReminderEnabled': _sedentaryReminderEnabled,
      'volume': _volume,
      'darkMode': _darkMode,
      'useSystemTheme': _useSystemTheme,
      'petSize': _petSize,
      'showBubble': _showBubble,
      'autoStartOnBoot': _autoStartOnBoot,
      'pipEnabled': _pipEnabled,
      'overlayEnabled': _overlayEnabled,
      'petOpacity': _petOpacity,
      'firstLaunch': _firstLaunch,
    };
  }
}

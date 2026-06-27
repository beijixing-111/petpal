import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'constants.dart';

/// 性能控制器 —— 监听设备状态，切换渲染/AI模式
///
/// 高性能模式：Live2D 动画 + 本地大模型推理
/// 降级模式：2D精灵图 + JSON关键词回复
class PerformanceController extends ChangeNotifier {
  // ========== 单例 ==========
  static PerformanceController? _instance;
  factory PerformanceController() {
    _instance ??= PerformanceController._();
    return _instance!;
  }
  PerformanceController._();

  // ========== MethodChannel ==========
  static const _channel = MethodChannel(AppConstants.channelPerformance);

  // ========== 状态 ==========
  bool _isLowPower = false;
  bool _isHighTemperature = false;
  String _currentMode = AppConstants.performanceModeHigh;
  double _batteryLevel = 1.0;
  double _deviceTemperature = 25.0; // 摄氏度

  // ========== Getters ==========
  bool get isLowPower => _isLowPower;
  bool get isHighTemperature => _isHighTemperature;
  bool get isDegradedMode => _currentMode == AppConstants.performanceModeDegraded;
  bool get isHighMode => _currentMode == AppConstants.performanceModeHigh;
  String get currentMode => _currentMode;
  double get batteryLevel => _batteryLevel;
  double get deviceTemperature => _deviceTemperature;

  StreamSubscription? _batterySubscription;
  Timer? _temperatureTimer;

  /// 外部设置的温度变化回调（由原生层调用时触发）
  void Function(double temperature)? onTemperatureChanged;

  // ========== 初始化监听 ==========
  void startMonitoring() {
    _setupBatteryListener();
    _startTemperaturePolling();
  }

  void _setupBatteryListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onBatteryChanged') {
        final level = (call.arguments as double?) ?? 1.0;
        _updateBatteryLevel(level);
      } else if (call.method == 'onTemperatureChanged') {
        final temp = (call.arguments as double?) ?? 25.0;
        _updateTemperature(temp);
      }
    });

    // 主动查询一次当前电量
    _queryBatteryLevel();
  }

  Future<void> _queryBatteryLevel() async {
    try {
      final level = await _channel.invokeMethod<double>('getBatteryLevel');
      if (level != null) {
        _updateBatteryLevel(level);
      }
    } catch (e) {
      debugPrint('[PerformanceController] 查询电量失败: $e');
    }
  }

  void _startTemperaturePolling() {
    // 每30秒轮询一次设备温度
    _temperatureTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final temp = await _channel.invokeMethod<double>('getDeviceTemperature');
        if (temp != null) {
          _updateTemperature(temp);
        }
      } catch (e) {
        // 某些设备可能不支持温度查询，静默忽略
      }
    });
  }

  // ========== 状态更新逻辑 ==========
  void _updateBatteryLevel(double level) {
    final wasLowPower = _isLowPower;
    _batteryLevel = level.clamp(0.0, 1.0);
    _isLowPower = _batteryLevel <= AppConstants.batteryLowThreshold;

    if (wasLowPower != _isLowPower) {
      _reevaluateMode();
    }
  }

  void _updateTemperature(double temperature) {
    final wasHighTemp = _isHighTemperature;
    _deviceTemperature = temperature;
    _isHighTemperature = temperature >= AppConstants.temperatureHighThreshold;

    onTemperatureChanged?.call(temperature);

    if (wasHighTemp != _isHighTemperature) {
      _reevaluateMode();
    }
  }

  /// 重新评估并切换性能模式
  void _reevaluateMode() {
    final newMode = (_isLowPower || _isHighTemperature)
        ? AppConstants.performanceModeDegraded
        : AppConstants.performanceModeHigh;

    if (_currentMode != newMode) {
      _currentMode = newMode;
      debugPrint('[PerformanceController] 性能模式切换: $newMode');
      notifyListeners();
    }
  }

  /// 手动切换性能模式（用户主动触发）
  void setMode(String mode) {
    if (mode != AppConstants.performanceModeHigh &&
        mode != AppConstants.performanceModeDegraded) {
      return;
    }
    if (_currentMode != mode) {
      _currentMode = mode;
      debugPrint('[PerformanceController] 手动切换模式: $mode');
      notifyListeners();
    }
  }

  // ========== 降级模式下的限制 ==========
  /// 在降级模式下是否允许使用AI对话
  bool get allowAIDialogue => isHighMode;
  /// 在降级模式下是否允许Live2D渲染
  bool get allowLive2D => isHighMode;

  // ========== 清理 ==========
  @override
  void dispose() {
    _batterySubscription?.cancel();
    _temperatureTimer?.cancel();
    super.dispose();
  }
}

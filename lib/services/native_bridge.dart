import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:petpal/core/constants.dart';

/// 原生平台桥接单例
///
/// 封装所有 Flutter ↔ 原生层 MethodChannel 调用。
/// 统一前缀 "com.petpal/"。
class NativeBridge {
  static NativeBridge? _instance;
  factory NativeBridge() {
    _instance ??= NativeBridge._();
    return _instance!;
  }
  NativeBridge._();

  // ========== Channels ==========
  static const _llamaChannel = MethodChannel(AppConstants.channelLlama);
  static const _performanceChannel = MethodChannel(AppConstants.channelPerformance);
  static const _pipChannel = MethodChannel(AppConstants.channelPip);
  static const _overlayChannel = MethodChannel(AppConstants.channelOverlay);
  static const _live2DChannel = MethodChannel(AppConstants.channelLive2D);
  static const _notificationChannel = MethodChannel(AppConstants.channelNotification);
  static const _modelDownloadChannel = MethodChannel(AppConstants.channelModelDownload);

  // ========== LLM 推理 ==========
  /// 是否正在进行推理
  bool _isInferring = false;
  bool get isInferring => _isInferring;

  /// 推理取消令牌（用于支持中断）
  Completer<String>? _inferCompleter;

  /// 发送 prompt 到本地大模型进行推理
  ///
  /// [prompt] 完整的提示词（包含 system prompt + 对话历史）
  /// 返回模型生成的文本回复
  /// 可通过 [cancelInfer] 中断推理
  Future<String> infer(String prompt) async {
    if (_isInferring) {
      throw StateError('已有推理正在进行中，请等待完成或先调用 cancelInfer()');
    }

    _isInferring = true;
    _inferCompleter = Completer<String>();

    try {
      final result = await _llamaChannel.invokeMethod<String>(
        'infer',
        {'prompt': prompt, 'temperature': AppConstants.aiTemperature},
      );

      if (_inferCompleter!.isCompleted) {
        throw Exception('推理已被中断');
      }

      _isInferring = false;
      final response = result ?? '';
      _inferCompleter!.complete(response);
      return response;
    } on PlatformException catch (e) {
      _isInferring = false;
      throw Exception('推理失败: ${e.message}');
    } catch (e) {
      _isInferring = false;
      rethrow;
    }
  }

  /// 中断当前推理
  Future<void> cancelInfer() async {
    if (!_isInferring || _inferCompleter == null) return;

    try {
      await _llamaChannel.invokeMethod('cancelInfer');
    } catch (e) {
      debugPrint('[NativeBridge] 取消推理失败: $e');
    }

    if (!_inferCompleter!.isCompleted) {
      _inferCompleter!.completeError(Exception('推理已被用户中断'));
    }

    _isInferring = false;
  }

  /// 流式推理（逐token返回）
  /// 返回一个 Stream，每次 yield 一个 token 片段
  Stream<String> inferStream(String prompt) async* {
    if (_isInferring) {
      throw StateError('已有推理正在进行中');
    }

    _isInferring = true;

    try {
      // 设置流式回调 handler
      await _llamaChannel.invokeMethod('startStreamInfer', {
        'prompt': prompt,
        'temperature': AppConstants.aiTemperature,
      });

      final streamController = StreamController<String>();

      _llamaChannel.setMethodCallHandler((call) async {
        if (call.method == 'onToken') {
          final token = call.arguments as String? ?? '';
          if (token == '<EOS>') {
            streamController.close();
            _isInferring = false;
          } else {
            streamController.add(token);
          }
        }
        return null;
      });

      yield* streamController.stream;
    } catch (e) {
      _isInferring = false;
      throw Exception('流式推理失败: $e');
    }
  }

  // ========== 模型下载 ==========
  /// 模型下载进度回调
  void Function(double progress, String status)? onModelDownloadProgress;

  /// 开始下载模型
  Future<void> downloadModel(String modelName) async {
    try {
      // 监听下载进度
      _modelDownloadChannel.setMethodCallHandler((call) async {
        if (call.method == 'onDownloadProgress') {
          final args = call.arguments as Map;
          final progress = (args['progress'] as num?)?.toDouble() ?? 0.0;
          final status = args['status'] as String? ?? '';
          onModelDownloadProgress?.call(progress, status);
        }
        return null;
      });

      await _modelDownloadChannel.invokeMethod('downloadModel', {
        'modelName': modelName,
      });
    } on PlatformException catch (e) {
      throw Exception('模型下载失败: ${e.message}');
    }
  }

  /// 取消模型下载
  Future<void> cancelModelDownload() async {
    await _modelDownloadChannel.invokeMethod('cancelDownload');
  }

  /// 检查模型是否已下载
  Future<bool> isModelDownloaded(String modelName) async {
    try {
      final result = await _modelDownloadChannel.invokeMethod<bool>(
        'isModelDownloaded',
        {'modelName': modelName},
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  // ========== 性能监控 ==========
  /// 获取当前电量 (0.0-1.0)
  Future<double> getBatteryLevel() async {
    try {
      final level = await _performanceChannel.invokeMethod<double>('getBatteryLevel');
      return level ?? 1.0;
    } catch (e) {
      return 1.0;
    }
  }

  /// 获取设备温度（摄氏度）
  Future<double> getDeviceTemperature() async {
    try {
      final temp = await _performanceChannel.invokeMethod<double>('getDeviceTemperature');
      return temp ?? 25.0;
    } catch (e) {
      return 25.0;
    }
  }

  // ========== PiP 画中画 ==========
  /// 进入画中画模式
  Future<bool> enterPipMode() async {
    try {
      final result = await _pipChannel.invokeMethod<bool>('enterPip');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 退出画中画模式
  Future<void> exitPipMode() async {
    await _pipChannel.invokeMethod('exitPip');
  }

  /// 是否处于画中画模式
  Future<bool> isInPipMode() async {
    try {
      final result = await _pipChannel.invokeMethod<bool>('isInPip');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  // ========== 悬浮窗权限 ==========
  /// 检查悬浮窗权限
  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _overlayChannel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 请求悬浮窗权限
  Future<bool> requestOverlayPermission() async {
    try {
      final result = await _overlayChannel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 显示/隐藏悬浮窗宠物
  Future<void> setOverlayVisible(bool visible) async {
    await _overlayChannel.invokeMethod('setVisible', visible);
  }

  // ========== Live2D 控制 ==========
  /// 设置 Live2D 动画
  Future<void> setLive2DAnimation(String animationName) async {
    await _live2DChannel.invokeMethod('setAnimation', animationName);
  }

  /// 设置 Live2D 透明度
  Future<void> setLive2DOpacity(double opacity) async {
    await _live2DChannel.invokeMethod('setOpacity', opacity.clamp(0.0, 1.0));
  }

  // ========== 本地通知 ==========
  /// 显示本地通知
  Future<void> showNotification(String title, String body) async {
    try {
      await _notificationChannel.invokeMethod('show', {
        'title': title,
        'body': body,
      });
    } catch (e) {
      debugPrint('[NativeBridge] 通知发送失败: $e');
    }
  }

  // ========== 错误处理工具 ==========
  /// 安全调用 MethodChannel，统一错误处理
  static Future<T?> safeInvoke<T>(
    MethodChannel channel,
    String method, [
    dynamic arguments,
  ]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      debugPrint('[NativeBridge] 平台未实现: ${channel.name}.$method');
      return null;
    } on PlatformException catch (e) {
      debugPrint('[NativeBridge] 平台异常: ${channel.name}.$method - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[NativeBridge] 未知错误: ${channel.name}.$method - $e');
      return null;
    }
  }
}

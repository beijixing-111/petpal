import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petpal/core/constants.dart';

/// 触摸热区与穿透管理器
///
/// 定义宠物的可点击区域（热区），热区外的触摸事件穿透到底层应用。
/// - Android：使用 WindowManager FLAG_NOT_TOUCH_MODAL
/// - iOS：PiP 触摸穿透处理
class HitTestManager {
  /// MethodChannel —— 通信原生层触摸配置
  static const _channel = MethodChannel('com.petpal/touch');

  /// 圆形热区中心（全局坐标，默认对应宠物头部）
  Offset _circleCenter = Offset.zero;
  /// 圆形热区半径
  double _circleRadius = 60;

  /// 矩形热区列表
  final List<_RectZone> _rectZones = [];

  /// Widget 全局偏移与尺寸
  Offset _globalOffset = Offset.zero;
  Size _widgetSize = Size.zero;
  double _scale = 1.0;

  HitTestManager() {
    _initTouchPassthrough();
  }

  /// 释放资源，恢复默认触摸模式
  void dispose() {
    _channel.invokeMethod('setTouchPassthrough', {'enabled': false});
  }

  /// 初始化原生触摸穿透
  Future<void> _initTouchPassthrough() async {
    try {
      await _channel.invokeMethod('setTouchPassthrough', {'enabled': true});
    } catch (e) {
      debugPrint('HitTestManager: 触摸穿透初始化失败 - $e');
    }
  }

  /// 更新热区坐标 —— Widget 移动或缩放时调用
  void updateZone({
    required Offset globalOffset,
    required Size widgetSize,
    required double scale,
  }) {
    _globalOffset = globalOffset;
    _widgetSize = widgetSize;
    _scale = scale;

    // 圆形热区：Widget 上部中央（宠物头部）
    _circleCenter = Offset(
      globalOffset.dx + widgetSize.width / 2,
      globalOffset.dy + widgetSize.height * 0.3,
    );
    _circleRadius = 60 * scale;

    // 矩形热区：宠物身体区域
    _rectZones.clear();
    _rectZones.add(_RectZone(
      rect: Rect.fromLTWH(
        globalOffset.dx + 20 * scale,
        globalOffset.dy + 40 * scale,
        widgetSize.width - 40 * scale,
        widgetSize.height - 40 * scale,
      ),
      label: 'body',
    ));
  }

  /// 判断给定全局坐标是否在热区内
  ///
  /// 返回 `true` 表示触摸命中宠物 → 消费事件
  /// 返回 `false` → 穿透到底层应用
  bool isPointInHotZone(Offset point) {
    if (_isInCircle(point, _circleCenter, _circleRadius)) return true;
    for (final zone in _rectZones) {
      if (zone.rect.contains(point)) return true;
    }
    return false;
  }

  bool _isInCircle(Offset point, Offset center, double radius) {
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    return (dx * dx + dy * dy) <= (radius * radius);
  }

  /// 获取圆形热区信息（调试用）
  ({Offset center, double radius}) get circleZone => (_circleCenter, _circleRadius);

  /// 获取矩形热区列表（调试用）
  List<Rect> get rectZones => _rectZones.map((z) => z.rect).toList();

  /// —— 触摸穿透开关 ——

  Future<void> enablePassthrough() async {
    await _channel.invokeMethod('setTouchPassthrough', {'enabled': true});
  }

  Future<void> disablePassthrough() async {
    await _channel.invokeMethod('setTouchPassthrough', {'enabled': false});
  }
}

/// 矩形热区内部数据类
class _RectZone {
  final Rect rect;
  final String label;
  const _RectZone({required this.rect, required this.label});
}

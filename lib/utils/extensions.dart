import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:petpal/providers/pet_provider.dart';
import 'package:petpal/providers/settings_provider.dart';
import 'package:petpal/core/performance_controller.dart';
import 'package:petpal/models/pet_state.dart';
import 'package:petpal/providers/reminder_provider.dart';

// ============================
//  DateTime 扩展
// ============================

extension DateTimeFormat on DateTime {
  /// "yyyy-MM-dd HH:mm"
  String get toStandard =>
      '${year}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')} '
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// "yyyy年MM月dd日"
  String get toChineseDate => '$year年${month}月${day}日';

  /// "MM/dd HH:mm"
  String get toShort =>
      '${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')} '
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// 相对时间：刚刚 / x分钟前 / x小时前 / x天前
  String get toRelative {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return toShort;
  }

  /// 是否为今天
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// 是否为昨天
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  /// 友好日期标签
  String get toFriendly {
    if (isToday) return '今天';
    if (isYesterday) return '昨天';
    return toShort;
  }

  /// 星期几
  String get weekdayChinese {
    const w = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return w[weekday - 1];
  }
}

// ============================
//  String 扩展
// ============================

extension StringUtils on String {
  bool get isBlank => trim().isEmpty;
  bool get isNotBlank => trim().isNotEmpty;

  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// 截断到 maxLength，超出加省略号
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$ellipsis';
  }

  /// 去除 HTML 标签
  String get stripHtml =>
      replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ');

  /// 限制行数
  String limitLines(int maxLines) {
    final lines = split('\n');
    if (lines.length <= maxLines) return this;
    return '${lines.take(maxLines).join('\n')}...';
  }

  /// 基于字符串生成固定颜色
  Color get toColor {
    int hash = 0;
    for (int i = 0; i < length; i++) {
      hash = codeUnitAt(i) + ((hash << 5) - hash);
    }
    return Color((hash & 0x00FFFFFF) | 0xFF000000);
  }
}

// ============================
//  BuildContext 扩展 —— 快捷访问 Provider
// ============================

extension ContextProviders on BuildContext {
  PetProvider get petProvider => read<PetProvider>();
  PetProvider get watchPet => watch<PetProvider>();
  PetState get petState => watch<PetProvider>().petState;

  SettingsProvider get settings => read<SettingsProvider>();
  SettingsProvider get watchSettings => watch<SettingsProvider>();

  PerformanceController get perf => read<PerformanceController>();
  PerformanceController get watchPerf => watch<PerformanceController>();

  ReminderProvider get reminder => read<ReminderProvider>();
  ReminderProvider get watchReminder => watch<ReminderProvider>();
}

// ============================
//  num 扩展
// ============================

extension NumUtils on num {
  /// 百分比字符串
  String get percent => '${(this * 100).toStringAsFixed(1)}%';

  /// 限制范围
  T clampBetween<T extends num>(T min, T max) {
    if (this < min) return min;
    if (this > max) return max;
    return this as T;
  }

  /// 文件大小格式化
  String get fileSize {
    final s = toDouble();
    if (s >= 1073741824) return '${(s / 1073741824).toStringAsFixed(2)} GB';
    if (s >= 1048576) return '${(s / 1048576).toStringAsFixed(2)} MB';
    if (s >= 1024) return '${(s / 1024).toStringAsFixed(2)} KB';
    return '${toStringAsFixed(0)} B';
  }
}

// ============================
//  Duration 扩展
// ============================

extension DurationFormat on Duration {
  String get toHHMMSS {
    final h = inHours.toString().padLeft(2, '0');
    final m = (inMinutes % 60).toString().padLeft(2, '0');
    final s = (inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get toMMSS {
    final m = inMinutes.toString().padLeft(2, '0');
    final s = (inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get toFriendly {
    if (inHours > 0) return '$inHours小时${inMinutes % 60}分钟';
    if (inMinutes > 0) return '$inMinutes分钟';
    return '$inSeconds秒';
  }
}

// ============================
//  List 扩展
// ============================

extension ListUtils<T> on List<T> {
  T? getOrNull(int index) => (index >= 0 && index < length) ? this[index] : null;

  List<T> separate(T separator) {
    if (length <= 1) return List.from(this);
    final result = <T>[];
    for (int i = 0; i < length; i++) {
      if (i > 0) result.add(separator);
      result.add(this[i]);
    }
    return result;
  }

  Map<K, List<T>> groupBy<K>(K Function(T) keyFn) {
    final map = <K, List<T>>{};
    for (final item in this) {
      map.putIfAbsent(keyFn(item), () => []).add(item);
    }
    return map;
  }
}

// ============================
//  Color 扩展
// ============================

extension ColorUtils on Color {
  Color lighten(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  String get toHex =>
      '#${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}'
      '${alpha.toRadixString(16).padLeft(2, '0')}';
}

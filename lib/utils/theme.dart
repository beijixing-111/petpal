import 'package:flutter/material.dart';
import 'package:petpal/core/constants.dart';

/// PetPal 应用主题配置
///
/// 浅色/深色双主题，统一管理颜色方案与文字样式。
class PetPalTheme {
  PetPalTheme._();

  /// 宠物主题主色 —— 使用 AppConstants 默认色
  static Color get primary => AppConstants.primaryColor;
  /// 辅助色
  static Color get secondary => AppConstants.secondaryColor;
  /// 背景色
  static Color get background => AppConstants.backgroundColor;
  /// 深色背景
  static Color get darkBackground => AppConstants.darkBackgroundColor;
  /// 卡片色
  static Color get card => AppConstants.cardColor;
  /// 深色卡片
  static Color get darkCard => AppConstants.darkCardColor;
  /// 金币金
  static Color get gold => AppConstants.goldColor;

  // ==================== 浅色主题 ====================
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      surface: card,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // —— AppBar ——
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF3E2723),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: Color(0xFF3E2723), fontSize: 18, fontWeight: FontWeight.w600),
      ),

      // —— 卡片 ——
      cardTheme: CardTheme(
        color: card,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // —— 按钮 ——
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: Color(0xFF6C63FF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // —— 输入框 ——
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2)),
      ),

      // —— 进度条 ——
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Color(0xFF6C63FF)),

      // —— 浮动按钮 ——
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),

      // —— 分割线 ——
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 0.5, space: 1),

      // —— 文字样式 ——
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF3E2723)),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF3E2723)),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF3E2723)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF3E2723)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF3E2723)),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFF8D6E63)),
      ),

      // —— 背景 ——
      scaffoldBackgroundColor: background,

      // —— SnackBar ——
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ==================== 深色主题 ====================
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: const Color(0xFFB388FF),
      secondary: secondary,
      surface: darkCard,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      ),

      cardTheme: CardTheme(
        color: darkCard,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      scaffoldBackgroundColor: darkBackground,
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Color(0xFFB388FF)),

      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
        bodySmall: TextStyle(fontSize: 12, color: Colors.white54),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:petpal/providers/pet_provider.dart';
import 'package:petpal/providers/settings_provider.dart';
import 'package:petpal/core/performance_controller.dart';
import 'package:petpal/providers/reminder_provider.dart';
import 'ui/desktop_pet/floating_pet_window.dart';
import 'ui/dialogues/chat_bubble.dart';
import 'ui/diary/diary_page.dart';
import 'ui/diary/summary_letter.dart';
import 'ui/onboarding/model_download_page.dart';
import 'ui/settings/settings_page.dart';
import 'utils/theme.dart';

/// PetPal 应用入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 SharedPreferences（SettingsProvider 内部管理）
  final settings = SettingsProvider();
  await settings.initialize();

  // 初始化宠物 Provider
  final petProvider = PetProvider();
  await petProvider.initialize();

  // 初始化性能监听
  PerformanceController().startMonitoring();

  runApp(PetPalApp(
    isFirstLaunch: settings.firstLaunch,
    settings: settings,
    petProvider: petProvider,
  ));
}

/// PetPal App 根组件，负责 Provider 注入、路由与主题
class PetPalApp extends StatelessWidget {
  final bool isFirstLaunch;
  final SettingsProvider settings;
  final PetProvider petProvider;

  const PetPalApp({
    super.key,
    required this.isFirstLaunch,
    required this.settings,
    required this.petProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 宠物状态管理（等级、饱食度、亲密度、金币等）
        ChangeNotifierProvider.value(value: petProvider),
        // 设置管理（提醒、音量、性能模式等）
        ChangeNotifierProvider.value(value: settings),
        // 性能模式控制（Live2D / 精灵图切换）
        ChangeNotifierProvider.value(value: PerformanceController()),
        // 提醒管理
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
      ],
      child: MaterialApp(
        title: 'PetPal',
        debugShowCheckedModeBanner: false,
        theme: PetPalTheme.lightTheme,
        darkTheme: PetPalTheme.darkTheme,
        themeMode: ThemeMode.system,
        // 首次启动 → 模型下载引导页，否则 → 悬浮窗主页
        initialRoute: isFirstLaunch ? '/onboarding' : '/',
        onGenerateRoute: _generateRoute,
        home: const FloatingPetWindow(),
      ),
    );
  }

  /// 路由表 —— 统一管理页面跳转
  static Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const FloatingPetWindow(),
          settings: settings,
        );
      case '/onboarding':
        return MaterialPageRoute(
          builder: (_) => const ModelDownloadPage(),
          settings: settings,
        );
      case '/chat':
        return MaterialPageRoute(
          builder: (_) => const ChatBubble(),
          settings: settings,
        );
      case '/diary':
        return MaterialPageRoute(
          builder: (_) => const DiaryPage(),
          settings: settings,
        );
      case '/summary':
        final entryId = settings.arguments as int? ?? 0;
        return MaterialPageRoute(
          builder: (_) => SummaryLetter(entryId: entryId),
          settings: settings,
        );
      case '/settings':
        return MaterialPageRoute(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const FloatingPetWindow(),
          settings: settings,
        );
    }
  }
}

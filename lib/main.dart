import 'package:flutter/foundation.dart' show kIsWeb;
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

  // Web 环境：直接启动，跳过原生初始化
  // 原生环境：完整初始化 SharedPreferences / sqflite / 性能监听
  late SettingsProvider settings;
  late PetProvider petProvider;

  try {
    settings = SettingsProvider();
    await settings.initialize();
  } catch (e) {
    // Web / 降级：使用默认设置
    debugPrint('[PetPal] Settings 初始化失败（Web 预期行为）: $e');
    settings = SettingsProvider();
  }

  try {
    petProvider = PetProvider();
    await petProvider.initialize();
  } catch (e) {
    // Web / 降级：使用默认宠物状态
    debugPrint('[PetPal] PetProvider 初始化失败（Web 预期行为）: $e');
    petProvider = PetProvider();
  }

  // 性能监听仅在原生平台有效，Web 跳过
  if (!kIsWeb) {
    try {
      PerformanceController().startMonitoring();
    } catch (e) {
      debugPrint('[PetPal] 性能监听启动失败: $e');
    }
  }

  runApp(PetPalApp(
    isFirstLaunch: false, // Web 跳过引导
    settings: settings,
    petProvider: petProvider,
  ));
}

/// PetPal App 根组件
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
        ChangeNotifierProvider.value(value: petProvider),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: PerformanceController()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()),
      ],
      child: MaterialApp(
        title: 'PetPal',
        debugShowCheckedModeBanner: false,
        theme: PetPalTheme.lightTheme,
        darkTheme: PetPalTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: isFirstLaunch ? '/onboarding' : '/',
        onGenerateRoute: _generateRoute,
        home: const FloatingPetWindow(),
      ),
    );
  }

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

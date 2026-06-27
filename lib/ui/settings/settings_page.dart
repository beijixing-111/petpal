import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:petpal/providers/settings_provider.dart';
import 'package:petpal/core/performance_controller.dart';
import 'package:petpal/core/constants.dart';
import 'package:petpal/services/native_bridge.dart';

/// 设置页面
///
/// 包含：AI 对话开关、提醒设置（番茄钟/喝水/久坐）、音量、
/// 性能模式、宠物大小、数据同步、关于、清空缓存。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final perf = context.watch<PerformanceController>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ========== AI 对话 ==========
          _sectionHeader('💬 AI 对话'),
          SwitchListTile(
            secondary: const Icon(Icons.smart_toy_outlined),
            title: const Text('AI 对话功能'),
            subtitle: const Text('关闭后使用关键词模式回复'),
            value: settings.aiDialogueEnabled,
            onChanged: (v) => settings.setAiDialogueEnabled(v),
          ),
          const Divider(),

          // ========== 提醒设置 ==========
          _sectionHeader('⏰ 提醒设置'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('提醒总开关'),
            value: settings.reminderEnabled,
            onChanged: (v) => settings.setReminderEnabled(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.timer_outlined),
            title: const Text('番茄钟提醒'),
            subtitle: const Text('每 25 分钟提醒休息'),
            value: settings.pomodoroEnabled,
            onChanged: settings.reminderEnabled ? (v) => settings.setPomodoroEnabled(v) : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.water_drop_outlined),
            title: const Text('喝水提醒'),
            subtitle: const Text('定时提醒补充水分'),
            value: settings.waterReminderEnabled,
            onChanged: settings.reminderEnabled ? (v) => settings.setWaterReminderEnabled(v) : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.accessibility_new_outlined),
            title: const Text('久坐提醒'),
            subtitle: const Text('坐太久时提醒起身活动'),
            value: settings.sedentaryReminderEnabled,
            onChanged: settings.reminderEnabled ? (v) => settings.setSedentaryReminderEnabled(v) : null,
          ),
          const Divider(),

          // ========== 声音 ==========
          _sectionHeader('🔊 声音'),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('对话气泡'),
            subtitle: const Text('显示宠物对话气泡'),
            value: settings.showBubble,
            onChanged: (v) => settings.setShowBubble(v),
          ),
          ListTile(
            leading: const Icon(Icons.volume_up_outlined),
            title: const Text('音量'),
            subtitle: Text('${(settings.volume * 100).round()}%'),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: settings.volume,
                min: 0, max: 1.0, divisions: 20,
                label: '${(settings.volume * 100).round()}%',
                onChanged: (v) => settings.setVolume(v),
              ),
            ),
          ),
          const Divider(),

          // ========== 性能模式 ==========
          _sectionHeader('⚡ 性能模式'),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('当前模式'),
            subtitle: Text(perf.isHighMode ? '高性能（Live2D + AI）' : '降级模式（精灵图 + 关键词）'),
            trailing: Switch(
              value: perf.isHighMode,
              onChanged: (v) => perf.setMode(v ? AppConstants.performanceModeHigh : AppConstants.performanceModeDegraded),
            ),
          ),
          if (perf.isDegradedMode)
            ListTile(
              leading: const Icon(Icons.battery_alert),
              title: const Text('降级原因'),
              subtitle: Text([
                if (perf.isLowPower) '电量过低（${(perf.batteryLevel * 100).round()}%）',
                if (perf.isHighTemperature) '设备过热（${perf.deviceTemperature.round()}°C）',
              ].join('；')),
            ),
          const Divider(),

          // ========== 宠物外观 ==========
          _sectionHeader('🐾 宠物外观'),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('宠物大小'),
            subtitle: Text(settings.petSize == 'small' ? '小' : settings.petSize == 'large' ? '大' : '中'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'small', label: Text('小')),
                ButtonSegment(value: 'medium', label: Text('中')),
                ButtonSegment(value: 'large', label: Text('大')),
              ],
              selected: {settings.petSize},
              onSelectionChanged: (s) => settings.setPetSize(s.first),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.opacity),
            title: const Text('宠物透明度'),
            subtitle: Text('${(settings.petOpacity * 100).round()}%'),
            trailing: SizedBox(
              width: 160,
              child: Slider(
                value: settings.petOpacity,
                min: 0.2, max: 1.0, divisions: 8,
                onChanged: (v) => settings.setPetOpacity(v),
              ),
            ),
          ),
          const Divider(),

          // ========== 悬浮窗 ==========
          _sectionHeader('🪟 悬浮窗'),
          SwitchListTile(
            secondary: const Icon(Icons.picture_in_picture),
            title: const Text('画中画模式'),
            subtitle: const Text('支持 iOS PiP 画中画'),
            value: settings.pipEnabled,
            onChanged: (v) => settings.setPipEnabled(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.layers_outlined),
            title: const Text('桌面悬浮窗'),
            subtitle: const Text('在其他 App 上方显示宠物'),
            value: settings.overlayEnabled,
            onChanged: (v) => settings.setOverlayEnabled(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.power_settings_new_outlined),
            title: const Text('开机自启'),
            subtitle: const Text('设备启动时自动运行 PetPal'),
            value: settings.autoStartOnBoot,
            onChanged: (v) => settings.setAutoStartOnBoot(v),
          ),
          const Divider(),

          // ========== 主题 ==========
          _sectionHeader('🎨 主题'),
          SwitchListTile(
            secondary: const Icon(Icons.brightness_6_outlined),
            title: const Text('跟随系统主题'),
            value: settings.useSystemTheme,
            onChanged: (v) => settings.setUseSystemTheme(v),
          ),
          if (!settings.useSystemTheme)
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('深色模式'),
              value: settings.darkMode,
              onChanged: (v) => settings.setDarkMode(v),
            ),
          const Divider(),

          // ========== 关于 & 缓存 ==========
          _sectionHeader('📋 其他'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于 PetPal'),
            subtitle: const Text('版本 1.0.0 · Flutter 3.19+'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('清空缓存'),
            subtitle: const Text('清理临时文件和模型缓存'),
            onTap: () => _clearCache(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('恢复默认设置'),
            onTap: () => _resetDefaults(context),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('关于 PetPal'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本：1.0.0'),
            SizedBox(height: 8),
            Text('PetPal 是一款跨平台智能桌面宠物应用，采用悬浮窗形式常驻桌面，陪伴你的每一天。'),
            SizedBox(height: 8),
            Text('技术栈：Flutter 3.19+ / Live2D / 本地大语言模型'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空缓存'),
        content: const Text('确定要清空所有缓存数据吗？这将删除临时文件和模型缓存。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // 通过 MethodChannel 调用原生层清空缓存
        await NativeBridge.safeInvoke(
          const MethodChannel(AppConstants.channelOverlay), 'clearCache',
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清空')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('清空失败: $e')));
      }
    }
  }

  Future<void> _resetDefaults(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('恢复默认设置'),
        content: const Text('确定要恢复所有设置为默认值吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<SettingsProvider>().resetToDefaults();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已恢复默认设置')));
    }
  }
}

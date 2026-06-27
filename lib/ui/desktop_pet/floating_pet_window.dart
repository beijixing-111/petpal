import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:petpal/providers/pet_provider.dart';
import 'package:petpal/core/performance_controller.dart';
import 'package:petpal/models/pet_state.dart';
import 'package:petpal/models/emotion.dart';
import 'package:petpal/core/constants.dart';
import 'hit_test_manager.dart';

/// 桌面悬浮窗 —— 宠物常驻桌面的主界面
///
/// 宠物居中展示，支持拖拽移动。
/// 点击宠物头部弹出菜单（对话/喂食/信息）。
/// 根据 [PerformanceController] 自动切换 Live2D / 精灵图渲染。
class FloatingPetWindow extends StatefulWidget {
  const FloatingPetWindow({super.key});

  @override
  State<FloatingPetWindow> createState() => _FloatingPetWindowState();
}

class _FloatingPetWindowState extends State<FloatingPetWindow> {
  /// 悬浮窗位置（相对于屏幕左上角）
  Offset _position = const Offset(100, 200);
  /// 宠物缩放比例
  double _scale = 1.0;
  /// 是否正在拖拽
  bool _isDragging = false;
  /// 热区管理器
  late HitTestManager _hitTestManager;

  @override
  void initState() {
    super.initState();
    _hitTestManager = HitTestManager();
  }

  @override
  void dispose() {
    _hitTestManager.dispose();
    super.dispose();
  }

  /// 更新热区坐标（与宠物位置/动画同步）
  void _updateHitZone(RenderBox? box) {
    if (box == null) return;
    final localToGlobal = box.localToGlobal(Offset.zero);
    final size = box.size;
    _hitTestManager.updateZone(
      globalOffset: localToGlobal,
      widgetSize: size,
      scale: _scale,
    );
  }

  /// 获取当前宠物渲染是否使用 Live2D
  bool _useLive2D(PerformanceController perf) => perf.isHighMode && perf.allowLive2D;

  @override
  Widget build(BuildContext context) {
    final petProvider = context.watch<PetProvider>();
    final pet = petProvider.petState;
    final emotion = petProvider.emotionState;
    final perf = context.watch<PerformanceController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // —— 可拖拽的宠物区域 ——
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: GestureDetector(
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanUpdate: (details) {
                setState(() {
                  _position += details.delta;
                  _position = Offset(
                    _position.dx.clamp(0, MediaQuery.of(context).size.width - 200),
                    _position.dy.clamp(0, MediaQuery.of(context).size.height - 200),
                  );
                });
              },
              onPanEnd: (_) => setState(() => _isDragging = false),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _updateHitZone(context.findRenderObject() as RenderBox?);
                  });
                  return _useLive2D(perf)
                      ? _buildLive2DPet(emotion, perf)
                      : _buildSpritePet(emotion);
                },
              ),
            ),
          ),

          // —— 拖拽时显示宠物状态栏 ——
          if (_isDragging)
            Positioned(
              left: _position.dx,
              top: _position.dy - 50,
              width: 200,
              child: _buildStatusBar(pet),
            ),

          // —— 点击宠物头部热区弹出菜单 ——
          Positioned(
            left: _position.dx + 70,
            top: _position.dy - 20,
            child: GestureDetector(
              onTap: () => _showPetMenu(context),
              child: Container(width: 60, height: 60, color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  /// Live2D 渲染（高性能模式）—— 通过原生 MethodChannel 驱动
  Widget _buildLive2DPet(EmotionState emotion, PerformanceController perf) {
    return SizedBox(
      width: 200 * _scale,
      height: 200 * _scale,
      child: AndroidView(
        viewType: AppConstants.channelLive2D,
        creationParams: {
          'animation': emotion.current.animationName,
          'intensity': emotion.intensity,
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }

  /// Emoji 宠物渲染 —— 大号 Emoji + 切换动画展示情绪
  Widget _buildSpritePet(EmotionState emotion) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 200 * _scale,
      height: 200 * _scale,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            emotion.current.emoji,
            key: ValueKey(emotion.current),
            style: TextStyle(fontSize: 100 * _scale),
          ),
        ),
      ),
    );
  }

  /// 宠物状态栏：饱食度 / 经验 / 亲密度
  Widget _buildStatusBar(PetState pet) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBar('饱食度', pet.fullnessProgress, AppConstants.fullnessBarColor),
          const SizedBox(height: 2),
          _buildBar('经验', pet.levelProgress, AppConstants.expBarColor),
          const SizedBox(height: 2),
          _buildBar('亲密度', pet.affectionProgress, AppConstants.affectionBarColor),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double ratio, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              color: color,
              minHeight: 8,
            ),
          ),
        ),
      ],
    );
  }

  /// 弹出宠物菜单：对话 / 喂食 / 信息
  void _showPetMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuItem(Icons.chat_bubble, '开始对话', () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/chat');
            }),
            _menuItem(Icons.fastfood, '喂食', () {
              Navigator.pop(ctx);
              context.read<PetProvider>().feed();
            }),
            _menuItem(Icons.card_giftcard, '每日金币', () {
              Navigator.pop(ctx);
              final claimed = context.read<PetProvider>().tryClaimDailyGold();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(claimed > 0 ? '领取了 $claimed 金币！' : '今天已经领取过了~')),
              );
            }),
            _menuItem(Icons.info_outline, '宠物信息', () {
              Navigator.pop(ctx);
              _showPetInfo(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }

  /// 宠物详细信息弹窗
  void _showPetInfo(BuildContext context) {
    final pet = context.read<PetProvider>().petState;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('宠物信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('等级：Lv.${pet.level}（${pet.evolutionStageName}）'),
            Text('经验：${pet.exp}/${pet.expToNextLevel}'),
            Text('饱食度：${pet.fullness}/${AppConstants.maxFullness}'),
            Text('亲密度：${pet.affection}/${AppConstants.maxAffection}'),
            Text('金币：${pet.gold}'),
            if (pet.accessory.isNotEmpty) Text('装扮：${pet.accessory}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ],
      ),
    );
  }
}

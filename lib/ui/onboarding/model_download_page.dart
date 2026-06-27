import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:petpal/services/native_bridge.dart';
import 'package:petpal/providers/settings_provider.dart';

/// 模型下载引导页 —— 首次启动展示
///
/// 宠物睡觉动画 + 头顶下载进度条，
/// 通过 [NativeBridge] 监听下载状态，完成后自动跳转主页。
class ModelDownloadPage extends StatefulWidget {
  const ModelDownloadPage({super.key});

  @override
  State<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends State<ModelDownloadPage>
    with SingleTickerProviderStateMixin {
  final _nativeBridge = NativeBridge();

  /// 下载状态
  _DownloadStatus _status = _DownloadStatus.preparing;
  /// 下载进度 0.0 - 1.0
  double _progress = 0.0;
  /// 状态描述（如"正在下载基础模型..."）
  String _statusText = '准备中...';
  /// 错误信息
  String? _errorMessage;
  /// 是否正在重试
  bool _isRetrying = false;
  /// 呼吸动画控制器
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _startDownload();
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  /// 启动模型下载
  Future<void> _startDownload() async {
    setState(() {
      _status = _DownloadStatus.downloading;
      _errorMessage = null;
    });

    // 监听下载进度
    _nativeBridge.onModelDownloadProgress = (progress, status) {
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _statusText = status;
        if (progress >= 1.0) {
          _status = _DownloadStatus.completed;
        }
      });
    };

    try {
      await _nativeBridge.downloadModel('petpal_base_model');
      if (mounted) {
        setState(() {
          _status = _DownloadStatus.completed;
          _progress = 1.0;
        });
        // 延迟 1 秒后标记首次启动完成并跳转主页
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.read<SettingsProvider>().completeFirstLaunch();
            Navigator.pushReplacementNamed(context, '/');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _DownloadStatus.error;
          _errorMessage = '下载失败: $e';
        });
      }
    }
  }

  /// 重试
  Future<void> _retryDownload() async {
    setState(() => _isRetrying = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isRetrying = false);
    _startDownload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.3),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // 标题
              Text('欢迎来到 PetPal', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.brown.shade700)),
              const SizedBox(height: 8),
              Text('正在为你准备 AI 宠物伙伴...', style: TextStyle(fontSize: 14, color: Colors.brown.shade400)),
              const SizedBox(height: 40),

              // 宠物睡觉动画
              AnimatedBuilder(
                animation: _breathAnimation,
                builder: (context, child) => Transform.scale(scale: _breathAnimation.value, child: child),
                child: SizedBox(
                  width: 180, height: 180,
                  child: Image.asset('assets/images/pet_sleeping.gif', fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.pets, size: 100, color: Colors.brown.shade300)),
                ),
              ),
              const SizedBox(height: 32),

              // 进度区域
              _buildProgressCard(theme),

              const Spacer(flex: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _status == _DownloadStatus.completed ? '准备完成，即将进入...' : '请保持网络连接稳定，下载过程中请勿退出 App',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              color: _status == _DownloadStatus.error ? Colors.red : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text('${(_progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.brown.shade700)),
          const SizedBox(height: 8),
          Text(_statusText, style: TextStyle(fontSize: 13, color: Colors.brown.shade500)),

          // 完成
          if (_status == _DownloadStatus.completed) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 20, color: Colors.green.shade500),
                const SizedBox(width: 6),
                Text('下载完成', style: TextStyle(fontSize: 14, color: Colors.green.shade600, fontWeight: FontWeight.w500)),
              ],
            ),
          ],

          // 错误 + 重试
          if (_status == _DownloadStatus.error) ...[
            const SizedBox(height: 8),
            Text(_errorMessage ?? '下载失败', style: TextStyle(fontSize: 12, color: Colors.red.shade400), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isRetrying ? null : _retryDownload,
              icon: _isRetrying
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(_isRetrying ? '重试中...' : '重新下载'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _DownloadStatus { preparing, downloading, completed, error }

import 'package:flutter/material.dart';
import 'package:petpal/services/dialogue_service.dart';
import 'package:petpal/models/emotion.dart';

/// 对话气泡页面 —— 用户与宠物的 AI 对话界面
///
/// 支持：
/// - 用户消息 / 宠物 AI 回复气泡
/// - 宠物回复含情绪动画头像 + 语音按钮
/// - 消息列表自动滚动
/// - 模型推理中的加载态
class ChatBubble extends StatefulWidget {
  const ChatBubble({super.key});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _dialogueService = DialogueService();

  /// 本地维护的消息列表（与 DialogueService.history 同步）
  List<DialogueMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dialogueService.onHistoryUpdated = () {
      if (mounted) {
        setState(() => _messages = List.from(_dialogueService.history));
        _scrollToBottom();
      }
    };
    // 初始加载已有历史
    _messages = List.from(_dialogueService.history);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 发送消息
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() => _isLoading = true);

    try {
      await _dialogueService.processUserInput(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('与宠物对话'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空对话',
            onPressed: () {
              // DialogueService 内部维护历史队列，此处仅清空本地显示
              setState(() => _messages.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // —— 消息列表 ——
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(_messages[index]),
                  ),
          ),

          // —— 加载状态（模型推理中） ——
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('正在思考...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),

          // —— 输入区域 ——
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('和你的宠物说点什么吧~',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  /// 单条消息气泡
  Widget _buildMessageBubble(DialogueMessage message) {
    final isUser = message.isUser;
    final emotion = message.petEmotion;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 宠物表情头像（仅宠物消息）
          if (!isUser && emotion != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundColor: Colors.brown.shade100,
                radius: 16,
                child: Text(emotion.emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
          if (!isUser && emotion == null)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                child: Icon(Icons.pets, size: 18),
              ),
            ),

          // 气泡主体
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.9)
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  // 语音按钮（仅宠物消息）
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildPlayAudioButton(message),
                    ),
                ],
              ),
            ),
          ),

          // 用户头像（右侧）
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                radius: 16,
                child: const Icon(Icons.person, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  /// 语音播放按钮
  Widget _buildPlayAudioButton(DialogueMessage message) {
    return GestureDetector(
      onTap: () {
        // TODO: 调用 MethodChannel 'com.petpal/tts' 播放语音
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音播放功能即将上线'), duration: Duration(seconds: 1)),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text('播放语音', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  /// 底部输入栏
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -1)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sendMessage,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

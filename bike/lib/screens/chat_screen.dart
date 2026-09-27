import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/friend_presence_label.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  final String subtitle;
  final String? friendUserId;
  final ChatService? service;
  final bool embedded;
  final bool isDirectChat;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
    required this.subtitle,
    this.friendUserId,
    this.service,
    this.embedded = false,
    this.isDirectChat = true,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final Stream<List<ChatMessage>> _messages;
  bool _sending = false;

  ChatService get _service => widget.service ?? ChatService();

  @override
  void initState() {
    super.initState();
    _messages = _service.watchMessages(widget.conversationId);
    _service.markConversationRead(widget.conversationId).ignore();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(
        conversationId: widget.conversationId,
        senderName: '',
        text: _controller.text,
      );
      _controller.clear();
      await _service.markConversationRead(widget.conversationId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Message not sent: $error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _service.currentUserId;
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: widget.embedded
          ? null
          : AppBar(
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title),
                  widget.friendUserId == null
                      ? Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: AppColors.themedGrey,
                            fontSize: 12,
                          ),
                        )
                      : FriendPresenceLabel(userId: widget.friendUserId!),
                ],
              ),
            ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'You no longer have access to this conversation.',
                      style: TextStyle(color: AppColors.themedGrey),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Start the conversation.',
                      style: TextStyle(color: AppColors.themedGrey),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message,
                      isMine: message.senderId == currentUserId,
                      isDirect: widget.isDirectChat,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.themedSurface,
                border: Border(
                  top: BorderSide(color: AppColors.themedGreyBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(color: AppColors.themedText),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: AppColors.themedGrey),
                        filled: true,
                        fillColor: AppColors.themedCard,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.themedGreyBorder,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.themedText,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool isDirect;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isDirect,
  });

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(message.sentAt).format(context);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isDirect && !isMine) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.orangeGlow,
              child: Text(
                _initials(message.senderName),
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 7),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? AppColors.orange : AppColors.themedCard,
              border: Border.all(
                color: isMine ? AppColors.orange : AppColors.themedGreyBorder,
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDirect && !isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        color: AppColors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  message.text,
                  style: TextStyle(color: AppColors.themedText, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: AppColors.themedGrey,
                        fontSize: 10,
                      ),
                    ),
                    if (isMine && isDirect) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.readBy.length > 1
                            ? Icons.done_all
                            : Icons.check,
                        size: 13,
                        color: AppColors.themedGrey,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase())
      .take(2)
      .join();
}

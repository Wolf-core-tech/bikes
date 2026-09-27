import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ChatService();
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(title: const Text('Chats')),
      body: StreamBuilder<List<ChatConversation>>(
        stream: service.watchConversations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load conversations.',
                style: TextStyle(color: AppColors.themedGrey),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conversations = snapshot.data!;
          if (conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 42,
                      color: AppColors.themedGrey,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No conversations yet.',
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Become friends with another rider to start chatting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.themedGrey),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: AppColors.themedGreyBorder,
              indent: 66,
            ),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final isSquad = conversation.kind == ChatKind.squad;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.orangeGlow,
                  child: Icon(
                    isSquad ? Icons.groups_outlined : Icons.person_outline,
                    color: AppColors.orange,
                  ),
                ),
                title: Text(
                  conversation.title,
                  style: TextStyle(
                    color: AppColors.themedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${isSquad ? 'Squad Chat' : 'Direct Chat'}${conversation.lastMessage == null ? '' : ' · ${conversation.lastMessage}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.themedGrey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (conversation.unreadCount > 0)
                      Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          conversation.unreadCount > 99
                              ? '99+'
                              : '${conversation.unreadCount}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.themedText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Icon(Icons.chevron_right, color: AppColors.themedGrey),
                  ],
                ),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(
                      conversationId: conversation.id,
                      title: conversation.title,
                      subtitle: isSquad ? 'Group Chat' : 'Friend',
                      friendUserId: isSquad
                          ? null
                          : conversation.participants.firstWhere(
                              (id) => id != service.currentUserId,
                            ),
                      isDirectChat: !isSquad,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

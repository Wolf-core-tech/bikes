import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/announcement_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../providers/notification_provider.dart';
import 'announcement_editor_screen.dart';
import 'notification_settings_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_photo.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(BuildContext context) async {
    try {
      await context.read<NotificationProvider>().markAllRead();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to mark notifications as read: $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>();
    final announcements = context.watch<AnnouncementProvider>();
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          if (notifications.unreadCount > 0)
            TextButton(
              onPressed: () => _markAllRead(context),
              child: const Text('Mark all as read'),
            ),
        ],
      ),
      floatingActionButton: announcements.canPublish
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const AnnouncementEditorScreen(),
                ),
              ),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Create announcement'),
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
            )
          : null,
      body: notifications.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            )
          : notifications.error != null
          ? Center(
              child: Text(
                'Notifications could not be loaded. Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.themedGrey),
              ),
            )
          : notifications.notifications.isEmpty
          ? const _EmptyNotifications()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _NotificationTile(
                notification: notifications.notifications[index],
              ),
            ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.notifications_none_outlined,
          size: 58,
          color: AppColors.orange,
        ),
        const SizedBox(height: 12),
        Text(
          "You're all caught up!",
          style: TextStyle(
            color: AppColors.themedText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _busy = false;

  AppNotification get notification => widget.notification;

  Future<void> _markAndOpen() async {
    try {
      await context.read<NotificationProvider>().markRead(notification.id);
      if (!mounted) return;
      if (notification.type == AppNotificationType.friendRequest ||
          notification.type == AppNotificationType.squadJoinRequest) {
        return;
      }
      NotificationService().openPayload({
        'notificationId': notification.id,
        'type': _wireType(notification.type),
        if (notification.relatedUserId != null)
          'relatedUserId': notification.relatedUserId,
        if (notification.relatedSquadId != null)
          'relatedSquadId': notification.relatedSquadId,
        if (notification.relatedChatId != null)
          'relatedChatId': notification.relatedChatId,
        if (notification.requestId != null) 'requestId': notification.requestId,
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open notification: $error')),
        );
      }
    }
  }

  Future<void> _respondToFriend(bool accept) async {
    final auth = context.read<AuthProvider>();
    final community = context.read<CommunityProvider>();
    final notifications = context.read<NotificationProvider>();
    final uid = auth.currentUser?.uid;
    if (uid == null || notification.requestId == null) return;
    setState(() => _busy = true);
    try {
      final result = await community.respondToRequest(
        notification.requestId!,
        accept,
        uid,
      );
      await notifications.markRead(notification.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to respond to request: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respondToSquad(bool approve) async {
    setState(() => _busy = true);
    try {
      await context.read<NotificationProvider>().respondToJoinRequest(
        notification: notification,
        approve: approve,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update squad request: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionableFriend =
        notification.type == AppNotificationType.friendRequest &&
        notification.status == 'pending';
    final actionableSquad =
        notification.type == AppNotificationType.squadJoinRequest &&
        notification.status == 'pending';
    final photo = notification.senderPhotoPath;
    return Material(
      color: AppColors.themedCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _busy ? null : _markAndOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? AppColors.themedGreyBorder
                  : AppColors.orange.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photo != null && photo.isNotEmpty)
                    ProfilePhoto(photoUrl: null, photoPath: photo, size: 46)
                  else
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: AppColors.orangeGlow,
                      child: Icon(
                        _icon(notification.type),
                        color: AppColors.orange,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            color: AppColors.themedText,
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: TextStyle(color: AppColors.themedGrey),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _relativeTime(notification.createdAt),
                          style: TextStyle(
                            color: AppColors.themedGrey,
                            fontSize: 11,
                          ),
                        ),
                        if (_resolvedStatus != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _resolvedStatus!,
                            style: TextStyle(
                              color: AppColors.orange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 5, left: 8),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(color: AppColors.orange),
                )
              else if (actionableFriend || actionableSquad) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => actionableFriend
                            ? _respondToFriend(false)
                            : _respondToSquad(false),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => actionableFriend
                            ? _respondToFriend(true)
                            : _respondToSquad(true),
                        child: Text(actionableSquad ? 'Approve' : 'Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _wireType(AppNotificationType type) => switch (type) {
    AppNotificationType.friendRequest => 'friend_request',
    AppNotificationType.friendRequestResult => 'friend_request_result',
    AppNotificationType.chatMessage => 'chat_message',
    AppNotificationType.squadMemberAdded => 'squad_member_added',
    AppNotificationType.squadJoinRequest => 'squad_join_request',
    AppNotificationType.squadJoinResult => 'squad_join_result',
    AppNotificationType.destinationReached => 'destination_reached',
    AppNotificationType.unknown => 'unknown',
  };

  String? get _resolvedStatus => switch (notification.status) {
    'accepted' || 'approved' => 'Accepted',
    'rejected' => 'Declined',
    _ => null,
  };

  IconData _icon(AppNotificationType type) => switch (type) {
    AppNotificationType.friendRequest ||
    AppNotificationType.friendRequestResult => Icons.person_add_alt_1,
    AppNotificationType.chatMessage => Icons.chat_bubble_outline,
    AppNotificationType.squadMemberAdded ||
    AppNotificationType.squadJoinRequest ||
    AppNotificationType.squadJoinResult => Icons.groups_outlined,
    AppNotificationType.destinationReached => Icons.flag_outlined,
    AppNotificationType.unknown => Icons.notifications_outlined,
  };

  String _relativeTime(DateTime time) {
    final elapsed = DateTime.now().difference(time);
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours} hr ago';
    if (elapsed.inDays < 7) return '${elapsed.inDays} day ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

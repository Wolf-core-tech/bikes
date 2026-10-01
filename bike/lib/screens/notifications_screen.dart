import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_models.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _busy = {};
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _respond(String requestId, bool accept) async {
    final auth = context.read<AuthProvider>();
    final currentId =
        auth.currentUser?.uid ??
        auth.currentUser?.email.trim().toLowerCase() ??
        '';
    setState(() => _busy.add(requestId));
    final message = await context.read<CommunityProvider>().respondToRequest(
          requestId,
          accept,
          currentId,
        );
    if (!mounted) return;
    setState(() => _busy.remove(requestId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: accept ? Colors.green : AppColors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final current = auth.currentUser;
    final community = context.watch<CommunityProvider>();
    final currentId =
        current?.uid ?? current?.email.trim().toLowerCase() ?? '';
    final received = community.receivedRequests(currentId);

    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (received.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${received.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: received.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: received.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = received[index];
                return _buildNotificationCard(request, index);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated bell icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orangeGlow,
                border: Border.all(color: AppColors.orange, width: 1.5),
              ),
              child: const Icon(
                Icons.notifications_none_outlined,
                color: AppColors.orange,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All caught up! 🎉',
            style: TextStyle(
              color: AppColors.themedText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending friend requests.\nGet out there and ride!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.themedGrey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(FriendRequest request, int index) {
    final isBusy = _busy.contains(request.id);

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 0.2 + index * 0.05),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(
            (index * 0.1).clamp(0.0, 0.8),
            1.0,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Interval((index * 0.1).clamp(0.0, 0.8), 1.0),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.themedCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.orange.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Orange ring avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.orangeGlow,
                          AppColors.orange.withValues(alpha: 0.15),
                        ],
                      ),
                      border:
                          Border.all(color: AppColors.orange, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _initials(request.senderName),
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.senderName,
                          style: TextStyle(
                            color: AppColors.themedText,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request.senderEmail,
                          style: TextStyle(
                            color: AppColors.themedGrey,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // New pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orangeGlow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: AppColors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Divider
              Divider(color: AppColors.themedGreyBorder, height: 1),

              const SizedBox(height: 12),

              // Notification message
              Row(
                children: [
                  const Icon(Icons.person_add_alt_1,
                      color: AppColors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sent you a friend request',
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action buttons
              isBusy
                  ? const Center(
                      child: SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.orange,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _respond(request.id, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.themedGrey,
                              side: BorderSide(
                                  color: AppColors.themedGreyBorder),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Ignore',
                              style:
                                  TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _respond(request.id, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: const Text(
                              'Accept',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) => name.trim().isEmpty
      ? '?'
      : name
          .trim()
          .split(RegExp(r'\s+'))
          .map((part) => part[0])
          .take(2)
          .join()
          .toUpperCase();
}

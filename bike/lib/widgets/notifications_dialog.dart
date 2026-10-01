import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../theme/app_theme.dart';

Future<void> showNotificationsDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _NotificationsDialog());

class _NotificationsDialog extends StatefulWidget {
  const _NotificationsDialog();

  @override
  State<_NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<_NotificationsDialog> {
  Future<void> _respond(String requestId, bool accept) async {
    final auth = context.read<AuthProvider>();
    final currentId =
        auth.currentUser?.uid ??
        auth.currentUser?.email.trim().toLowerCase() ??
        '';
    final message = await context.read<CommunityProvider>().respondToRequest(
      requestId,
      accept,
      currentId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: accept ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final current = auth.currentUser;
    final community = context.watch<CommunityProvider>();
    final currentId = current?.uid ?? current?.email.trim().toLowerCase() ?? '';
    final received = community.receivedRequests(currentId);

    return AlertDialog(
      backgroundColor: AppColors.themedSurface,
      title: const Row(
        children: [
          Icon(Icons.notifications_active, color: AppColors.orange),
          SizedBox(width: 8),
          Text('Notifications'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: received.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No new notifications.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.themedGrey),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: received.length,
                itemBuilder: (context, index) {
                  final request = received[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.themedCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.themedGreyBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.orangeGlow,
                              radius: 18,
                              child: Text(
                                _initials(request.senderName),
                                style: const TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request.senderName,
                                    style: TextStyle(
                                      color: AppColors.themedText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    request.senderEmail,
                                    style: TextStyle(
                                      color: AppColors.themedGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sent you a friend request.',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _respond(request.id, false),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.themedGrey,
                              ),
                              child: const Text('Ignore'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _respond(request.id, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Accept'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FriendPresenceLabel extends StatelessWidget {
  final String userId;

  const FriendPresenceLabel({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final lastSeen = (data?['lastSeen'] as Timestamp?)?.toDate();
        final isOnline =
            data?['isOnline'] == true &&
            lastSeen != null &&
            DateTime.now().difference(lastSeen) < const Duration(minutes: 2);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.success : AppColors.themedGrey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                color: isOnline ? AppColors.success : AppColors.themedGrey,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  friendRequest,
  friendRequestResult,
  chatMessage,
  squadMemberAdded,
  squadJoinRequest,
  squadJoinResult,
  destinationReached,
  unknown,
}

class AppNotification {
  final String id;
  final String recipientUserId;
  final String? senderUserId;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedUserId;
  final String? relatedSquadId;
  final String? relatedChatId;
  final String? relatedRideId;
  final String? requestId;
  final String? status;
  final String? senderPhotoPath;

  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.senderUserId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.relatedUserId,
    required this.relatedSquadId,
    required this.relatedChatId,
    required this.relatedRideId,
    required this.requestId,
    required this.status,
    required this.senderPhotoPath,
  });

  factory AppNotification.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return AppNotification(
      id: document.id,
      recipientUserId: data['recipientUserId'] as String? ?? '',
      senderUserId: data['senderUserId'] as String?,
      type: _parseType(data['type'] as String?),
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      relatedUserId: data['relatedUserId'] as String?,
      relatedSquadId: data['relatedSquadId'] as String?,
      relatedChatId: data['relatedChatId'] as String?,
      relatedRideId: data['relatedRideId'] as String?,
      requestId: data['requestId'] as String?,
      status: data['status'] as String?,
      senderPhotoPath: data['senderPhotoPath'] as String?,
    );
  }

  static AppNotificationType _parseType(String? value) => switch (value) {
    'friend_request' => AppNotificationType.friendRequest,
    'friend_request_result' => AppNotificationType.friendRequestResult,
    'chat_message' => AppNotificationType.chatMessage,
    'squad_member_added' => AppNotificationType.squadMemberAdded,
    'squad_join_request' => AppNotificationType.squadJoinRequest,
    'squad_join_result' => AppNotificationType.squadJoinResult,
    'destination_reached' => AppNotificationType.destinationReached,
    _ => AppNotificationType.unknown,
  };
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatKind { direct, squad }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime sentAt;
  final List<String> readBy;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    required this.readBy,
  });

  factory ChatMessage.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return ChatMessage(
      id: document.id,
      senderId: data['senderId'] as String,
      senderName: data['senderName'] as String? ?? 'Rider',
      text: data['text'] as String,
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(data['readBy'] as List? ?? const []),
    );
  }
}

class ChatConversation {
  final String id;
  final ChatKind kind;
  final List<String> participants;
  final String? squadId;
  final String title;
  final String? lastMessage;
  final DateTime? updatedAt;
  final int unreadCount;

  const ChatConversation({
    required this.id,
    required this.kind,
    required this.participants,
    required this.squadId,
    required this.title,
    required this.lastMessage,
    required this.updatedAt,
    required this.unreadCount,
  });

  factory ChatConversation.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    String currentUserId,
  ) => ChatConversation.fromData(document.id, document.data(), currentUserId);

  factory ChatConversation.fromData(
    String id,
    Map<String, dynamic> data,
    String currentUserId,
  ) {
    final participants = List<String>.from(data['participants'] as List? ?? []);
    final otherUserId = participants.firstWhere(
      (participant) => participant != currentUserId,
      orElse: () => '',
    );
    final participantNames = Map<String, dynamic>.from(
      data['participantNames'] as Map? ?? const {},
    );
    final unreadCounts = Map<String, dynamic>.from(
      data['unreadCounts'] as Map? ?? const {},
    );
    return ChatConversation(
      id: id,
      kind: data['kind'] == 'squad' ? ChatKind.squad : ChatKind.direct,
      participants: participants,
      squadId: data['squadId'] as String?,
      title:
          data['title'] as String? ??
          participantNames[otherUserId] as String? ??
          (otherUserId.isEmpty ? 'Squad Chat' : otherUserId),
      lastMessage: data['lastMessage'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      unreadCount: (unreadCounts[currentUserId] as num?)?.toInt() ?? 0,
    );
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_models.dart';

class ChatService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String get _currentUserId {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw StateError('Sign in to use chat.');
    return userId;
  }

  String get currentUserId => _currentUserId;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  String _directId(String firstId, String secondId) {
    final users = [firstId, secondId]..sort();
    return 'direct_${users[0]}_${users[1]}';
  }

  Future<String> openDirectConversation(
    String otherUserId, {
    String? otherUserName,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == otherUserId) {
      throw StateError('You cannot message yourself.');
    }
    final id = _directId(currentUserId, otherUserId);
    final ref = _conversations.doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        transaction.set(ref, {
          'kind': 'direct',
          'participants': [currentUserId, otherUserId]..sort(),
          'participantNames': {
            currentUserId: _auth.currentUser?.displayName ?? 'Rider',
            otherUserId: otherUserName ?? 'Rider',
          },
          'unreadCounts': {currentUserId: 0, otherUserId: 0},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    return id;
  }

  Future<String> openSquadConversation({
    required String squadId,
    required String squadName,
  }) async {
    final currentUserId = _currentUserId;
    final membership = await _firestore
        .collection('squads')
        .doc(squadId)
        .collection('members')
        .doc(currentUserId)
        .get();
    if (!membership.exists) throw StateError('You are not a squad member.');
    final memberships = await _firestore
        .collection('squads')
        .doc(squadId)
        .collection('members')
        .get();
    final participantIds = memberships.docs
        .map((document) => document.id)
        .toList();

    final id = 'squad_$squadId';
    final ref = _conversations.doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        transaction.set(ref, {
          'kind': 'squad',
          'squadId': squadId,
          'title': squadName,
          'participants': participantIds,
          'unreadCounts': {for (final id in participantIds) id: 0},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(ref, {'participants': participantIds});
      }
    });
    return id;
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) =>
      _conversations
          .doc(conversationId)
          .collection('messages')
          .orderBy('sentAt')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map(ChatMessage.fromDocument).toList(),
          );

  Stream<List<ChatConversation>> watchConversations() {
    final currentUserId = _currentUserId;
    final conversations = <String, ChatConversation>{};
    final directConversationIds = <String>{};
    final squadConversationIds = <String>{};
    final conversationSubscriptions =
        <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    late final StreamController<List<ChatConversation>> controller;

    void publish() {
      final items = conversations.values.toList()
        ..sort(
          (first, second) =>
              (second.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    first.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  ),
        );
      if (!controller.isClosed) controller.add(items);
    }

    Future<void> watchIds(Set<String> ids) async {
      for (final id in conversationSubscriptions.keys.toList()) {
        if (!ids.contains(id)) {
          await conversationSubscriptions.remove(id)?.cancel();
          conversations.remove(id);
        }
      }
      for (final id in ids) {
        if (conversationSubscriptions.containsKey(id)) continue;
        conversationSubscriptions[id] = _conversations
            .doc(id)
            .snapshots()
            .listen((snapshot) {
              if (snapshot.exists) {
                conversations[id] = ChatConversation.fromData(
                  id,
                  snapshot.data()!,
                  currentUserId,
                );
              } else {
                conversations.remove(id);
              }
              publish();
            }, onError: controller.addError);
      }
      publish();
    }

    late StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    friendshipSubscription;
    late StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    squadSubscription;
    controller = StreamController<List<ChatConversation>>(
      onListen: () {
        friendshipSubscription = _firestore
            .collection('friendships')
            .where('members', arrayContains: currentUserId)
            .snapshots()
            .listen((snapshot) {
              directConversationIds.clear();
              for (final document in snapshot.docs) {
                final members = List<String>.from(
                  document.data()['members'] as List,
                );
                final otherId = members.firstWhere(
                  (member) => member != currentUserId,
                  orElse: () => '',
                );
                if (otherId.isNotEmpty) {
                  directConversationIds.add(_directId(currentUserId, otherId));
                }
              }
              unawaited(
                watchIds({...directConversationIds, ...squadConversationIds}),
              );
            }, onError: controller.addError);
        squadSubscription = _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('squads')
            .snapshots()
            .listen((snapshot) {
              squadConversationIds
                ..clear()
                ..addAll(
                  snapshot.docs.map((document) => 'squad_${document.id}'),
                );
              unawaited(
                watchIds({...directConversationIds, ...squadConversationIds}),
              );
            }, onError: controller.addError);
      },
      onCancel: () async {
        await friendshipSubscription.cancel();
        await squadSubscription.cancel();
        for (final subscription in conversationSubscriptions.values) {
          await subscription.cancel();
        }
        conversationSubscriptions.clear();
        conversations.clear();
      },
    );
    return controller.stream;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderName,
    required String text,
  }) async {
    final currentUserId = _currentUserId;
    final message = text.trim();
    if (message.isEmpty) return;
    final conversation = _conversations.doc(conversationId);
    final messageRef = conversation.collection('messages').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(conversation);
      if (!snapshot.exists) throw StateError('Conversation not found.');
      final data = snapshot.data()!;
      final participants = List<String>.from(
        data['participants'] as List? ?? [],
      );
      final unreadCounts = Map<String, dynamic>.from(
        data['unreadCounts'] as Map? ?? const {},
      );
      for (final participant in participants) {
        unreadCounts[participant] = participant == currentUserId
            ? (unreadCounts[participant] as num?)?.toInt() ?? 0
            : ((unreadCounts[participant] as num?)?.toInt() ?? 0) + 1;
      }
      transaction.set(messageRef, {
        'senderId': currentUserId,
        'senderName': _auth.currentUser?.displayName ?? senderName,
        'text': message,
        'sentAt': FieldValue.serverTimestamp(),
        'readBy': [currentUserId],
      });
      transaction.update(conversation, {
        'lastMessage': message,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts': unreadCounts,
      });
    });
  }

  Future<void> markConversationRead(String conversationId) async {
    final currentUserId = _currentUserId;
    final messages = await _conversations
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .get();
    final unread = messages.docs
        .where(
          (document) => !List<String>.from(
            document.data()['readBy'] as List? ?? [],
          ).contains(currentUserId),
        )
        .toList();
    for (var index = 0; index < unread.length; index += 400) {
      final batch = _firestore.batch();
      for (final document in unread.skip(index).take(400)) {
        batch.update(document.reference, {
          'readBy': FieldValue.arrayUnion([currentUserId]),
        });
      }
      await batch.commit();
    }
    await _conversations.doc(conversationId).update({
      'unreadCounts.$currentUserId': 0,
    });
  }
}

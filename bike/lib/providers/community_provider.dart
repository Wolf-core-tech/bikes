import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_models.dart';
import '../models/user_model.dart';

class CommunityProvider extends ChangeNotifier {
  static const _invitationsKey = 'squad_invitations';

  List<FriendRequest> _requests = [];
  List<SquadInvitation> _invitations = [];
  Map<String, List<String>> _friends = {};
  bool _loaded = false;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  StreamSubscription<User?>? _authSubscription;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _relationshipSubscriptions = [];

  CommunityProvider() {
    _load();
    try {
      _authSubscription = _auth.authStateChanges().listen(_loadRelationships);
    } catch (_) {}
  }

  List<FriendRequest> get requests => List.unmodifiable(_requests);
  bool get isLoaded => _loaded;

  List<FriendRequest> receivedRequests(String userId) => _requests
      .where(
        (request) =>
            request.receiverId == userId &&
            request.status == FriendRequestStatus.pending,
      )
      .toList();

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    for (final subscription in _relationshipSubscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  bool areFriends(String firstId, String secondId) =>
      _friends[firstId]?.contains(secondId) ?? false;

  List<UserModel> friendsFor(String userId, List<UserModel> users) {
    final friendIds = _friends[userId.trim()] ?? const <String>[];
    return users.where((user) {
      final matchesUid =
          user.uid != null && friendIds.contains(user.uid!.trim());
      final matchesEmail = friendIds.contains(user.email.trim().toLowerCase());
      return matchesUid || matchesEmail;
    }).toList();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _invitations = _decodeList(
      prefs.getString(_invitationsKey),
      SquadInvitation.fromJson,
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadRelationships(User? user) async {
    for (final subscription in _relationshipSubscriptions) {
      await subscription.cancel();
    }
    _relationshipSubscriptions.clear();
    if (user == null) {
      _requests = [];
      _friends = {};
      notifyListeners();
      return;
    }
    QuerySnapshot<Map<String, dynamic>>? received;
    QuerySnapshot<Map<String, dynamic>>? sent;
    void updateRequests() {
      final documents = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      if (received != null) documents.addAll(received!.docs);
      if (sent != null) documents.addAll(sent!.docs);
      _requests = documents
          .map(
            (document) =>
                FriendRequest.fromJson({...document.data(), 'id': document.id}),
          )
          .toList();
      notifyListeners();
    }

    _relationshipSubscriptions.add(
      _firestore
          .collection('friendRequests')
          .where('receiverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(
            (snapshot) {
              received = snapshot;
              updateRequests();
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Unable to load received friend requests: $error');
            },
          ),
    );
    _relationshipSubscriptions.add(
      _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(
            (snapshot) {
              sent = snapshot;
              updateRequests();
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Unable to load sent friend requests: $error');
            },
          ),
    );
    _relationshipSubscriptions.add(
      _firestore
          .collection('friendships')
          .where('members', arrayContains: user.uid)
          .snapshots()
          .listen(
            (friendships) {
              _friends = {
                user.uid: friendships.docs
                    .expand(
                      (document) =>
                          List<String>.from(document.data()['members'] as List),
                    )
                    .where((memberId) => memberId != user.uid)
                    .toList(),
              };
              notifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Unable to load friendships: $error');
            },
          ),
    );

    QuerySnapshot<Map<String, dynamic>>? receivedByEmail;
    void updateRequestsByEmail() {
      if (receivedByEmail == null) return;
      final existing = _requests.map((r) => r.id).toSet();
      final extra = receivedByEmail!.docs
          .where((d) => !existing.contains(d.id))
          .map(
            (document) =>
                FriendRequest.fromJson({...document.data(), 'id': document.id}),
          )
          .toList();
      if (extra.isNotEmpty) {
        _requests = [..._requests, ...extra];
        notifyListeners();
      }
    }

    // Also listen by receiverEmail so users with stub IDs still see requests
    _relationshipSubscriptions.add(
      _firestore
          .collection('friendRequests')
          .where('receiverEmail', isEqualTo: user.email)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(
            (snapshot) {
              receivedByEmail = snapshot;
              updateRequestsByEmail();
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Unable to load friend requests by email: $error');
            },
          ),
    );
  }

  List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) parse) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => parse(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _invitationsKey,
      jsonEncode(
        _invitations.map((invitation) => invitation.toJson()).toList(),
      ),
    );
  }

  Future<UserModel?> searchUser(String query, String currentId) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final Map<String, dynamic>? riderData;
    if (normalized.contains('@')) {
      final result = await FirebaseFunctions.instance
          .httpsCallable('findRiderByEmail')
          .call<Map<String, dynamic>?>({'email': normalized});
      riderData = result.data;
    } else {
      final matches = await _firestore
          .collection('publicProfiles')
          .orderBy('nameLower')
          .startAt([normalized])
          .endAt(['$normalized\uf8ff'])
          .limit(20)
          .get();
      riderData = matches.docs.isEmpty
          ? null
          : {...matches.docs.first.data(), 'uid': matches.docs.first.id};
    }

    if (riderData == null) return null;
    final user = UserModel.fromMap({
      'uid': riderData['uid'],
      'name': riderData['name'] as String? ?? 'Rider',
      'photoPath': riderData['photoPath'] as String?,
      'photoUrl': riderData['photoUrl'] as String?,
      'email': '',
      'phone': '',
      'password': '',
    });
    if (_userId(user) == currentId) {
      throw Exception('You cannot add yourself.');
    }
    return user;
  }

  String _userId(UserModel user) => user.uid?.trim().isNotEmpty == true
      ? user.uid!.trim()
      : user.email.trim().toLowerCase();

  String requestStatus(String currentId, String otherId) {
    if (areFriends(currentId, otherId)) return 'Friends';
    final sent = _requests.where(
      (request) =>
          request.senderId == currentId && request.receiverId == otherId,
    );
    if (sent.any((request) => request.status == FriendRequestStatus.pending)) {
      return 'Request Sent';
    }
    if (_requests.any(
      (request) =>
          request.senderId == otherId &&
          request.receiverId == currentId &&
          request.status == FriendRequestStatus.pending,
    )) {
      return 'Request Received';
    }
    return 'Send Request';
  }

  Future<String> sendFriendRequest({
    required UserModel sender,
    required UserModel receiver,
  }) async {
    final senderId = _userId(sender);
    final receiverId = _userId(receiver);
    if (senderId == receiverId) return 'You cannot add yourself.';
    if (areFriends(senderId, receiverId)) {
      return 'This rider is already your friend.';
    }
    if (_requests.any(
      (request) =>
          request.senderId == senderId &&
          request.receiverId == receiverId &&
          request.status == FriendRequestStatus.pending,
    )) {
      return 'Friend request already sent.';
    }
    final now = DateTime.now();
    final requestRef = _firestore.collection('friendRequests').doc();
    final request = FriendRequest(
      id: requestRef.id,
      senderId: senderId,
      receiverId: receiverId,
      senderName: sender.name,
      senderEmail: sender.email,
      receiverName: receiver.name,
      receiverEmail: receiver.email,
      status: FriendRequestStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    await requestRef.set(request.toJson());
    _requests.add(request);
    notifyListeners();
    return 'Friend request sent.';
  }

  Future<String> respondToRequest(
    String requestId,
    bool accept,
    String currentId,
  ) async {
    final index = _requests.indexWhere((request) => request.id == requestId);
    if (index == -1 || _requests[index].receiverId != currentId) {
      return 'This request is no longer available.';
    }
    final request = _requests[index];
    final updatedRequest = request.copyWith(
      status: accept
          ? FriendRequestStatus.accepted
          : FriendRequestStatus.rejected,
      updatedAt: DateTime.now(),
    );
    final batch = _firestore.batch();
    batch.update(
      _firestore.collection('friendRequests').doc(requestId),
      updatedRequest.toJson()..remove('id'),
    );
    if (accept) {
      final members = [request.senderId, request.receiverId]..sort();
      final friendshipId = '${members[0]}_${members[1]}';
      batch.set(_firestore.collection('friendships').doc(friendshipId), {
        'members': members,
        'accepted': true,
        'requestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    _requests[index] = updatedRequest;
    if (accept) {
      _friends.putIfAbsent(request.senderId, () => []).add(request.receiverId);
      _friends.putIfAbsent(request.receiverId, () => []).add(request.senderId);
    }
    notifyListeners();
    return accept ? 'Rider added as a friend.' : 'Friend request rejected.';
  }

  Future<void> removeFriend(String currentId, UserModel friend) async {
    // Find any friendship document containing both users
    final query = await _firestore
        .collection('friendships')
        .where('members', arrayContains: currentId)
        .get();

    final batch = _firestore.batch();
    for (final doc in query.docs) {
      final members = List<String>.from(doc.data()['members'] as List);
      final matchesUid =
          friend.uid != null && members.contains(friend.uid!.trim());
      final matchesEmail = members.contains(friend.email.trim().toLowerCase());
      if (matchesUid || matchesEmail) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();

    // Optimistically update local state
    if (friend.uid != null) {
      _friends[currentId]?.remove(friend.uid!.trim());
      _friends[friend.uid!.trim()]?.remove(currentId);
    }
    _friends[currentId]?.remove(friend.email.trim().toLowerCase());
    _friends[friend.email.trim().toLowerCase()]?.remove(currentId);
    notifyListeners();
  }

  Future<SquadInvitation> createInvitation({
    required String squadId,
    required String squadName,
    required String creatorId,
  }) async {
    final random = Random.secure();
    String code;
    do {
      code = (1000 + random.nextInt(9000)).toString();
    } while (_invitations.any(
      (invitation) =>
          invitation.code == code &&
          invitation.status == InvitationStatus.active &&
          !invitation.isExpired,
    ));

    final now = DateTime.now();
    final invitation = SquadInvitation(
      id: 'invitation_${now.microsecondsSinceEpoch}',
      squadId: squadId,
      squadName: squadName,
      createdBy: creatorId,
      code: code,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      status: InvitationStatus.active,
    );
    _invitations.add(invitation);
    await _firestore.collection('squadInvitations').doc(code).set({
      'squadId': squadId,
      'squadName': squadName,
      'creatorId': creatorId,
      'status': 'active',
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(invitation.expiresAt),
    });
    await _persist();
    notifyListeners();
    return invitation;
  }

  Future<String> validateAndUseInvitation({
    required String code,
    required String currentUserId,
    required bool Function(String squadId) isAlreadyMember,
    required Future<void> Function(String squadId) addMember,
  }) async {
    final invitationIndex = _invitations.indexWhere(
      (invitation) => invitation.code == code.trim(),
    );
    final inviteRef = _firestore
        .collection('squadInvitations')
        .doc(code.trim());
    final inviteSnapshot = await inviteRef.get();
    if (!inviteSnapshot.exists) return 'Invalid invitation code.';
    final inviteData = inviteSnapshot.data()!;
    if (inviteData['status'] != 'active') {
      return 'This invitation code has already been used.';
    }
    final expiresAt = (inviteData['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) {
      return 'This invitation code has expired.';
    }
    final squadId = inviteData['squadId'] as String;
    if (isAlreadyMember(squadId)) {
      return 'You are already a member of this squad.';
    }
    if (inviteData['creatorId'] == currentUserId) {
      return 'You cannot join your own squad invitation.';
    }

    final batch = _firestore.batch();
    batch.update(inviteRef, {'status': 'used', 'claimedBy': currentUserId});
    batch.set(
      _firestore
          .collection('squads')
          .doc(squadId)
          .collection('members')
          .doc(currentUserId),
      {
        'uid': currentUserId,
        'name': _auth.currentUser?.displayName ?? 'Rider',
        'role': 'midRider',
        'invitationCode': code.trim(),
        'joinedAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
    if (invitationIndex != -1) {
      _invitations[invitationIndex] = _invitations[invitationIndex].copyWith(
        status: InvitationStatus.used,
      );
    }
    await addMember(squadId);
    await _persist();
    notifyListeners();
    return 'You joined the squad successfully.';
  }
}

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/community_models.dart';
import '../models/user_model.dart';

class CommunityProvider extends ChangeNotifier {
  static const _requestsKey = 'friend_requests';
  static const _invitationsKey = 'squad_invitations';
  static const _friendsKey = 'friend_relationships';

  List<FriendRequest> _requests = [];
  List<SquadInvitation> _invitations = [];
  Map<String, List<String>> _friends = {};
  bool _loaded = false;

  CommunityProvider() {
    _load();
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

  bool areFriends(String firstId, String secondId) =>
      _friends[firstId]?.contains(secondId) ?? false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _requests = _decodeList(
      prefs.getString(_requestsKey),
      FriendRequest.fromJson,
    );
    _invitations = _decodeList(
      prefs.getString(_invitationsKey),
      SquadInvitation.fromJson,
    );
    final friendsJson = prefs.getString(_friendsKey);
    if (friendsJson != null) {
      final decoded = jsonDecode(friendsJson) as Map<String, dynamic>;
      _friends = decoded.map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      );
    }
    _loaded = true;
    notifyListeners();
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
      _requestsKey,
      jsonEncode(_requests.map((request) => request.toJson()).toList()),
    );
    await prefs.setString(
      _invitationsKey,
      jsonEncode(
        _invitations.map((invitation) => invitation.toJson()).toList(),
      ),
    );
    await prefs.setString(_friendsKey, jsonEncode(_friends));
  }

  UserModel? findUser(List<UserModel> users, String query, String currentId) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try {
      return users.firstWhere((user) {
        final userId = _userId(user);
        return userId != currentId &&
            (user.email.toLowerCase() == normalized ||
                user.name.toLowerCase() == normalized ||
                user.name.toLowerCase().contains(normalized));
      });
    } catch (_) {
      return null;
    }
  }

  String _userId(UserModel user) => user.email.trim().toLowerCase();

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
    _requests.add(
      FriendRequest(
        id: 'request_${now.microsecondsSinceEpoch}',
        senderId: senderId,
        receiverId: receiverId,
        senderName: sender.name,
        senderEmail: sender.email,
        receiverName: receiver.name,
        receiverEmail: receiver.email,
        status: FriendRequestStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _persist();
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
    _requests[index] = request.copyWith(
      status: accept
          ? FriendRequestStatus.accepted
          : FriendRequestStatus.rejected,
      updatedAt: DateTime.now(),
    );
    if (accept) {
      _friends.putIfAbsent(request.senderId, () => []).add(request.receiverId);
      _friends.putIfAbsent(request.receiverId, () => []).add(request.senderId);
    }
    await _persist();
    notifyListeners();
    return accept ? 'Rider added as a friend.' : 'Friend request rejected.';
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
    await _persist();
    notifyListeners();
    return invitation;
  }

  Future<String> validateAndUseInvitation({
    required String code,
    required String currentUserId,
    required bool Function(String squadId) isAlreadyMember,
    required bool Function(String squadId) squadExists,
    required void Function(String squadId) addMember,
  }) async {
    final invitationIndex = _invitations.indexWhere(
      (invitation) => invitation.code == code.trim(),
    );
    if (invitationIndex == -1) return 'Invalid invitation code.';
    final invitation = _invitations[invitationIndex];
    if (invitation.status != InvitationStatus.active) {
      return 'This invitation code has already been used.';
    }
    if (invitation.isExpired) return 'This invitation code has expired.';
    if (!squadExists(invitation.squadId)) return 'This squad does not exist.';
    if (isAlreadyMember(invitation.squadId)) {
      return 'You are already a member of this squad.';
    }
    if (invitation.createdBy == currentUserId) {
      return 'You cannot join your own squad invitation.';
    }

    addMember(invitation.squadId);
    _invitations[invitationIndex] = invitation.copyWith(
      status: InvitationStatus.used,
    );
    await _persist();
    notifyListeners();
    return 'You joined the squad successfully.';
  }
}

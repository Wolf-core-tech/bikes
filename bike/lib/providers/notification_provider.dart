import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _service;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _notificationSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _unreadSubscription;
  List<AppNotification> _notifications = [];
  String? _userId;
  Object? _error;
  int _unreadCount = 0;
  bool _loading = true;
  static const int pageSize = 100;

  NotificationProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? service,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _service = service ?? NotificationService() {
    _authSubscription = _auth.authStateChanges().listen(
      _listenToUser,
      onError: (Object error) {
        _error = error;
        _loading = false;
        notifyListeners();
      },
    );
    _listenToUser(_auth.currentUser);
  }

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;
  Object? get error => _error;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  Future<void> _listenToUser(User? user) async {
    await _notificationSubscription?.cancel();
    await _unreadSubscription?.cancel();
    _notificationSubscription = null;
    _unreadSubscription = null;
    _notifications = [];
    _unreadCount = 0;
    _userId = user?.uid;
    _loading = user != null;
    _error = null;
    notifyListeners();
    if (user == null) {
      _loading = false;
      notifyListeners();
      return;
    }
    _notificationSubscription = _collection(user.uid)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .listen(
          (snapshot) {
            _notifications = snapshot.docs
                .map(AppNotification.fromDocument)
                .toList();
            _loading = false;
            _error = null;
            notifyListeners();
          },
          onError: (Object error) {
            _error = error;
            _loading = false;
            notifyListeners();
          },
        );
    _unreadSubscription = _collection(user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            _unreadCount = snapshot.docs.length;
            notifyListeners();
          },
          onError: (Object error) {
            _error = error;
            _loading = false;
            notifyListeners();
          },
        );
    await _service.updateToken();
  }

  Future<void> markRead(String notificationId) async {
    final uid = _userId;
    if (uid == null) return;
    await _collection(uid).doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllRead() async {
    final uid = _userId;
    if (uid == null) return;
    final snapshot = await _collection(
      uid,
    ).where('isRead', isEqualTo: false).get();
    final unread = snapshot.docs;
    for (var index = 0; index < unread.length; index += 400) {
      final batch = _firestore.batch();
      for (final item in unread.skip(index).take(400)) {
        batch.update(item.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  Future<void> markAllReceivedRead() => markAllRead();

  Future<void> recordDestinationReached({
    required String rideId,
    required String? destinationName,
  }) async {
    final uid = _userId;
    if (uid == null) return;
    final trimmedName = destinationName?.trim();
    final safeName = trimmedName == null || trimmedName.isEmpty
        ? null
        : trimmedName.length > 150
        ? trimmedName.substring(0, 150)
        : trimmedName;
    final message = safeName == null
        ? 'Destination reached!'
        : 'Destination reached: $safeName';
    final id = 'destination_$rideId';
    Object? localNotificationError;
    StackTrace? localNotificationStackTrace;
    try {
      await _service.showLocalEvent(
        id: id,
        type: 'destination_reached',
        title: 'Destination reached!',
        body: message,
        relatedRideId: rideId,
      );
    } catch (error, stackTrace) {
      localNotificationError = error;
      localNotificationStackTrace = stackTrace;
    }
    final reference = _collection(uid).doc(id);
    final created = await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) return false;
      transaction.set(reference, {
        'notificationId': id,
        'recipientUserId': uid,
        'senderUserId': null,
        'type': 'destination_reached',
        'title': 'Destination reached!',
        'body': message,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'relatedRideId': rideId,
      });
      return true;
    });
    if (!created) return;
    if (localNotificationError != null) {
      Error.throwWithStackTrace(
        localNotificationError,
        localNotificationStackTrace!,
      );
    }
  }

  Future<void> requestToJoinSquad({
    required String squadId,
    required String squadName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to request to join a squad.');
    final request = _firestore
        .collection('squadJoinRequests')
        .doc('${squadId}_${user.uid}');
    final existingMembership = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('squads')
        .doc(squadId)
        .get();
    if (existingMembership.exists) {
      throw StateError('You have already joined this squad.');
    }
    await request.set({
      'squadId': squadId,
      'squadName': squadName,
      'requesterId': user.uid,
      'requesterName': user.displayName ?? 'Rider',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondToJoinRequest({
    required AppNotification notification,
    required bool approve,
  }) async {
    final squadId = notification.relatedSquadId;
    final requestId = notification.requestId;
    if (squadId == null || requestId == null) {
      throw StateError('This squad request is incomplete.');
    }
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to respond to this request.');
    final requesterId = notification.senderUserId;
    if (requesterId == null || requesterId.isEmpty) {
      throw StateError('This squad request has no requester.');
    }
    final squadRef = _firestore.collection('squads').doc(squadId);
    final memberRef = squadRef.collection('members').doc(requesterId);
    final requestRef = _firestore
        .collection('squadJoinRequests')
        .doc(requestId);
    await _firestore.runTransaction((transaction) async {
      final request = await transaction.get(requestRef);
      if (!request.exists || request.data()?['status'] != 'pending') {
        throw StateError('This squad request is no longer pending.');
      }
      final squad = await transaction.get(squadRef);
      final reviewerMembership = await transaction.get(
        squadRef.collection('members').doc(user.uid),
      );
      final reviewerRole = reviewerMembership.data()?['role'];
      final isAuthorizedReviewer =
          squad.data()?['ownerId'] == user.uid ||
          reviewerRole == 'leader' ||
          reviewerRole == 'coLeader';
      if (!squad.exists || !isAuthorizedReviewer) {
        throw StateError('Only a squad leader can respond.');
      }
      if (approve) {
        transaction.set(memberRef, {
          'uid': requesterId,
          'name': request.data()!['requesterName'] as String? ?? 'Rider',
          'role': 'midRider',
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.update(requestRef, {
        'status': approve ? 'approved' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedBy': user.uid,
      });
    });
    await markRead(notification.id);
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_notificationSubscription?.cancel());
    unawaited(_unreadSubscription?.cancel());
    super.dispose();
  }
}

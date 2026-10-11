import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/announcement.dart';

class AnnouncementProvider extends ChangeNotifier {
  AnnouncementProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance {
    _authSubscription = _auth.authStateChanges().listen(_bindUser);
    _bindUser(_auth.currentUser);
  }

  static const int pageSize = 25;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _feedSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _draftSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _readSubscription;
  final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> _older = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _firstPage = [];
  Set<String> _readIds = {};
  String? _userId;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _canPublish = false;
  Future<int>? _eligibleCount;

  List<Announcement> get announcements {
    final documents = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final document in _older.values) document.id: document,
      for (final document in _firstPage) document.id: document,
    }.values.toList()
      ..sort((first, second) {
        final firstDate =
            (first.data()['publishedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final secondDate =
            (second.data()['publishedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return secondDate.compareTo(firstDate);
      });
    return documents.map(Announcement.fromDocument).toList();
  }

  List<Announcement> get drafts => _drafts
      .map(Announcement.fromDocument)
      .toList(growable: false);

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _drafts = [];
  int get unreadCount => _firstPage
      .where((document) => !_readIds.contains(document.id))
      .length;
  bool isRead(String announcementId) => _readIds.contains(announcementId);
  bool get canPublish => _canPublish;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  Object? get error => _error;
  String? get userId => _userId;

  Future<int> eligibleUserCount() async {
    return (_eligibleCount ??= _firestore
            .collection('publicProfiles')
            .count()
            .get()
            .then((result) => result.count ?? 0));
  }

  CollectionReference<Map<String, dynamic>> get _announcements =>
      _firestore.collection('announcements');

  Future<void> _bindUser(User? user) async {
    await _feedSubscription?.cancel();
    await _draftSubscription?.cancel();
    await _readSubscription?.cancel();
    _feedSubscription = null;
    _draftSubscription = null;
    _readSubscription = null;
    _userId = user?.uid;
    _eligibleCount = null;
    _firstPage = [];
    _older.clear();
    _readIds = {};
    _drafts = [];
    _cursor = null;
    _hasMore = true;
    _error = null;
    _loading = user != null;
    _canPublish = false;
    notifyListeners();
    if (user == null) {
      _loading = false;
      notifyListeners();
      return;
    }
    _canPublish = true;
    notifyListeners();
    _feedSubscription = _announcements
        .where('isPublished', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .listen(
          (snapshot) {
            _firstPage = snapshot.docs;
            _cursor = snapshot.docs.isEmpty ? null : snapshot.docs.last;
            _hasMore = snapshot.docs.length == pageSize;
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
    _draftSubscription = _announcements
        .where('creatorUserId', isEqualTo: user.uid)
        .where('isPublished', isEqualTo: false)
        .limit(50)
        .snapshots()
        .listen(
          (snapshot) {
            _drafts = snapshot.docs;
            notifyListeners();
          },
          onError: (Object error) {
            _error = error;
            notifyListeners();
          },
        );
    _readSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('announcementReads')
        .orderBy('viewedAt', descending: true)
        .limit(1000)
        .snapshots()
        .listen(
          (snapshot) {
            _readIds = snapshot.docs.map((document) => document.id).toSet();
            notifyListeners();
          },
          onError: (Object error) {
            _error = error;
            notifyListeners();
          },
        );
  }

  Future<void> refresh() async {
    final user = _auth.currentUser;
    if (user == null) return;
    _loading = true;
    _error = null;
    _older.clear();
    _cursor = null;
    _hasMore = true;
    notifyListeners();
    try {
      final snapshot = await _announcements
          .where('isPublished', isEqualTo: true)
          .orderBy('publishedAt', descending: true)
          .limit(pageSize)
          .get(const GetOptions(source: Source.server));
      _firstPage = snapshot.docs;
      _cursor = snapshot.docs.isEmpty ? null : snapshot.docs.last;
      _hasMore = snapshot.docs.length == pageSize;
      _loading = false;
      notifyListeners();
    } catch (error) {
      _error = error;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    if (_loadingMore || !_hasMore || cursor == null) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final snapshot = await _announcements
          .where('isPublished', isEqualTo: true)
          .orderBy('publishedAt', descending: true)
          .startAfterDocument(cursor)
          .limit(pageSize)
          .get();
      for (final document in snapshot.docs) {
        _older[document.id] = document;
      }
      _cursor = snapshot.docs.isEmpty ? null : snapshot.docs.last;
      _hasMore = snapshot.docs.length == pageSize;
      _error = null;
    } catch (error) {
      _error = error;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String announcementId) async {
    final uid = _userId;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('announcementReads')
        .doc(announcementId)
        .set({
          'announcementId': announcementId,
          'userId': uid,
          'viewedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> markAllRead() async {
    final uid = _userId;
    if (uid == null) return;
    final batch = _firestore.batch();
    for (final announcement in announcements) {
      if (_readIds.contains(announcement.id)) continue;
      batch.set(
        _firestore
            .collection('users')
            .doc(uid)
            .collection('announcementReads')
            .doc(announcement.id),
        {
          'announcementId': announcement.id,
          'userId': uid,
          'viewedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
  }

  Future<void> saveDraft({
    String? announcementId,
    required String title,
    required String description,
    required AnnouncementCategory category,
    required String creatorDisplayName,
    required String timeZone,
    DateTime? eventDateTime,
    String? eventLocalDateTime,
    String? meetingPlace,
    String? meetingAddress,
    double? latitude,
    double? longitude,
    String? additionalInstructions,
    DateTime? rsvpDeadline,
    String? rsvpDeadlineLocalDateTime,
  }) async {
    await _save(
      announcementId: announcementId,
      title: title,
      description: description,
      category: category,
      creatorDisplayName: creatorDisplayName,
      timeZone: timeZone,
      eventDateTime: eventDateTime,
      eventLocalDateTime: eventLocalDateTime,
      meetingPlace: meetingPlace,
      meetingAddress: meetingAddress,
      latitude: latitude,
      longitude: longitude,
      additionalInstructions: additionalInstructions,
      rsvpDeadline: rsvpDeadline,
      rsvpDeadlineLocalDateTime: rsvpDeadlineLocalDateTime,
      publish: false,
    );
  }

  Future<void> publish({
    String? announcementId,
    required String title,
    required String description,
    required AnnouncementCategory category,
    required String creatorDisplayName,
    required String timeZone,
    DateTime? eventDateTime,
    String? eventLocalDateTime,
    String? meetingPlace,
    String? meetingAddress,
    double? latitude,
    double? longitude,
    String? additionalInstructions,
    DateTime? rsvpDeadline,
    String? rsvpDeadlineLocalDateTime,
  }) async {
    if (title.trim().isEmpty || description.trim().isEmpty) {
      throw ArgumentError('Enter a title and description.');
    }
    if ((category == AnnouncementCategory.ride ||
            category == AnnouncementCategory.meetup) &&
        (eventDateTime == null ||
            meetingPlace == null ||
            meetingPlace.trim().isEmpty)) {
      throw ArgumentError('Rides and meetups need a date, time and place.');
    }
    if (eventDateTime != null && eventDateTime.isBefore(DateTime.now())) {
      throw ArgumentError('Choose a date and time in the future.');
    }
    if (rsvpDeadline != null &&
        eventDateTime != null &&
        !rsvpDeadline.isBefore(eventDateTime)) {
      throw ArgumentError('The RSVP deadline must be before the event.');
    }
    await _save(
      announcementId: announcementId,
      title: title,
      description: description,
      category: category,
      creatorDisplayName: creatorDisplayName,
      timeZone: timeZone,
      eventDateTime: eventDateTime,
      eventLocalDateTime: eventLocalDateTime,
      meetingPlace: meetingPlace,
      meetingAddress: meetingAddress,
      latitude: latitude,
      longitude: longitude,
      additionalInstructions: additionalInstructions,
      rsvpDeadline: rsvpDeadline,
      rsvpDeadlineLocalDateTime: rsvpDeadlineLocalDateTime,
      publish: true,
    );
  }

  Future<void> _save({
    required String? announcementId,
    required String title,
    required String description,
    required AnnouncementCategory category,
    required String creatorDisplayName,
    required String timeZone,
    required DateTime? eventDateTime,
    required String? eventLocalDateTime,
    required String? meetingPlace,
    required String? meetingAddress,
    required double? latitude,
    required double? longitude,
    required String? additionalInstructions,
    required DateTime? rsvpDeadline,
    required String? rsvpDeadlineLocalDateTime,
    required bool publish,
  }) async {
    final uid = _userId;
    if (uid == null) {
      throw StateError('Sign in to create an announcement.');
    }
    final reference = announcementId == null
        ? _announcements.doc()
        : _announcements.doc(announcementId);
    final existing = announcementId == null ? null : await reference.get();
    if (existing != null &&
        (!existing.exists ||
            existing.data()?['creatorUserId'] != uid ||
            existing.data()?['status'] == 'cancelled')) {
      throw StateError('This announcement cannot be edited by your account.');
    }
    final data = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'category': announcementCategoryWire(category),
      'creatorUserId': uid,
      'creatorDisplayName': creatorDisplayName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'eventDateTime': eventDateTime == null
          ? null
          : Timestamp.fromDate(eventDateTime.toUtc()),
      'eventLocalDateTime': eventLocalDateTime,
      'timeZone': timeZone,
      'meetingPlace': meetingPlace?.trim(),
      'meetingAddress': meetingAddress?.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'additionalInstructions': additionalInstructions?.trim(),
      'rsvpDeadline': rsvpDeadline == null
          ? null
          : Timestamp.fromDate(rsvpDeadline.toUtc()),
      'rsvpDeadlineLocalDateTime': rsvpDeadlineLocalDateTime,
      'status': publish ? 'published' : 'draft',
      'isPublished': publish,
      if (publish && (existing?.data()?['publishedAt'] == null))
        'publishedAt': FieldValue.serverTimestamp(),
    };
    if (existing == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await reference.set(data, SetOptions(merge: existing != null));
  }

  Future<void> cancel(Announcement announcement, String message) async {
    final uid = _userId;
    if (uid == null || announcement.creatorUserId != uid) {
      throw StateError('Only the announcement creator can cancel this event.');
    }
    await _announcements.doc(announcement.id).update({
      'status': 'cancelled',
      'cancellationMessage': message.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDraft(Announcement announcement) async {
    final uid = _userId;
    if (uid == null ||
        announcement.creatorUserId != uid ||
        announcement.isPublished) {
      throw StateError('Only the draft creator can delete this draft.');
    }
    await _announcements.doc(announcement.id).delete();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRsvp(
    String announcementId,
  ) {
    final uid = _userId;
    if (uid == null) return const Stream.empty();
    return _announcements
        .doc(announcementId)
        .collection('responses')
        .doc(uid)
        .snapshots();
  }

  Future<void> respond({
    required Announcement announcement,
    required AnnouncementRsvp response,
    required String displayName,
  }) async {
    final uid = _userId;
    if (uid == null) throw StateError('Sign in to respond.');
    if (announcement.isCancelled) {
      throw StateError('This event has been cancelled.');
    }
    final now = DateTime.now().toUtc();
    if (announcement.rsvpDeadline != null &&
        announcement.rsvpDeadline!.isBefore(now)) {
      throw StateError('The RSVP deadline has passed.');
    }
    final profile = await _firestore.collection('publicProfiles').doc(uid).get();
    if (!profile.exists) {
      throw StateError('Your public rider profile is not available yet.');
    }
    final profileData = profile.data()!;
    final responseRef = _announcements
        .doc(announcement.id)
        .collection('responses')
        .doc(uid);
    final previous = await responseRef.get();
    final responseData = <String, dynamic>{
          'userId': uid,
          'displayName': profileData['name'] as String? ?? displayName,
          'photoPath': profileData['photoPath'],
          'response': announcementRsvpWire(response),
          'updatedAt': FieldValue.serverTimestamp(),
          if (!previous.exists) 'createdAt': FieldValue.serverTimestamp(),
        };
    await responseRef.set(responseData, SetOptions(merge: previous.exists));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchResponses(
    String announcementId,
  ) => _announcements
      .doc(announcementId)
      .collection('responses')
      .orderBy('updatedAt', descending: true)
      .snapshots();

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_feedSubscription?.cancel());
    unawaited(_draftSubscription?.cancel());
    unawaited(_readSubscription?.cancel());
    super.dispose();
  }
}

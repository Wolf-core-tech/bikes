import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

const _messagesChannel = AndroidNotificationChannel(
  'bikes_messages',
  'Messages',
  description: 'Direct and squad chat messages.',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  sound: RawResourceAndroidNotificationSound('notification_sound'),
);
const _friendRequestsChannel = AndroidNotificationChannel(
  'bikes_friend_requests',
  'Friend requests',
  description: 'Friend requests and responses.',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  sound: RawResourceAndroidNotificationSound('notification_sound'),
);
const _squadChannel = AndroidNotificationChannel(
  'bikes_squads',
  'Squad notifications',
  description: 'Squad membership and join requests.',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  sound: RawResourceAndroidNotificationSound('notification_sound'),
);
const _rideChannel = AndroidNotificationChannel(
  'bikes_ride_alerts',
  'Ride alerts',
  description: 'Important alerts during your ride.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  sound: RawResourceAndroidNotificationSound('notification_sound'),
);
const _announcementsChannel = AndroidNotificationChannel(
  'bikes_announcements',
  'Announcements',
  description: 'Rides, meetups and important community updates.',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  sound: RawResourceAndroidNotificationSound('notification_sound'),
);
const _baseNotificationChannels = [
  _messagesChannel,
  _friendRequestsChannel,
  _squadChannel,
  _rideChannel,
  _announcementsChannel,
];

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initializeLocalNotifications();
  if (message.notification == null) {
    await NotificationService().showRemoteMessage(message);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  Future<void>? _initializeFuture;
  void Function(Map<String, dynamic> payload)? _tapHandler;
  Map<String, dynamic>? _pendingPayload;
  bool _navigationReady = false;
  bool _localInitialized = false;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _customNotificationsEnabled = true;

  Future<void> init() => _initializeFuture ??= _initialize();

  Future<void> _initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _loadPreferences();
    await initializeLocalNotifications();
    await _createAndroidChannels();
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
      showRemoteMessage,
    );
    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleRemoteTap,
    );
    _tokenSubscription ??= _messaging.onTokenRefresh.listen(
      (_) => unawaited(updateToken()),
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _queuePayload(initialMessage.data);
    final launchDetails = await _local.getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload != null && payload.isNotEmpty) {
      _queuePayload(_decodePayload(payload));
    }
    await updateToken();
  }

  Future<void> initializeLocalNotifications() async {
    if (_localInitialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _local.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _queuePayload(_decodePayload(payload));
      },
    );
    _localInitialized = true;
    await _createAndroidChannels();
  }

  Future<void> _createAndroidChannels() async {
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    for (final channel in _baseNotificationChannels) {
      for (final sound in [true, false]) {
        for (final vibration in [true, false]) {
          final variant = _channelVariant(channel, sound, vibration);
          await android.createNotificationChannel(variant);
        }
      }
    }
  }

  Future<void> _loadPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      if (data == null) return;
      _notificationsEnabled = data['notificationsEnabled'] as bool? ?? true;
      _soundEnabled = data['notificationSoundEnabled'] as bool? ?? true;
      _vibrationEnabled = data['notificationVibrationEnabled'] as bool? ?? true;
      _customNotificationsEnabled =
          data['customNotificationsEnabled'] as bool? ?? true;
    } on FirebaseException catch (error) {
      debugPrint('Unable to load notification preferences (${error.code}).');
    }
  }

  Future<void> setPreferences({
    required bool notificationsEnabled,
    required bool soundEnabled,
    required bool vibrationEnabled,
    required bool customNotificationsEnabled,
  }) async {
    _notificationsEnabled = notificationsEnabled;
    _soundEnabled = soundEnabled;
    _vibrationEnabled = vibrationEnabled;
    _customNotificationsEnabled = customNotificationsEnabled;
  }

  Future<void> previewVibration() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      const id = 2147483000;
      await _local.show(
        id: id,
        title: '',
        body: '',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'settings_vibration_preview',
            'Settings vibration preview',
            channelDescription: 'Vibration when testing notification settings.',
            importance: Importance.min,
            priority: Priority.min,
            playSound: false,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 1000]),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await _local.cancel(id: id);
      return;
    }
    await HapticFeedback.vibrate();
  }

  void setTapHandler(void Function(Map<String, dynamic>) handler) {
    _tapHandler = handler;
    _dispatchPending();
  }

  void setNavigationReady(bool ready) {
    _navigationReady = ready;
    _dispatchPending();
  }

  void openPayload(Map<String, dynamic> payload) => _queuePayload(payload);

  void _handleRemoteTap(RemoteMessage message) => _queuePayload(message.data);

  void _queuePayload(Map<String, dynamic> payload) {
    if (payload.isEmpty) return;
    _pendingPayload = Map<String, dynamic>.from(payload);
    _dispatchPending();
  }

  void _dispatchPending() {
    final handler = _tapHandler;
    final payload = _pendingPayload;
    if (!_navigationReady || handler == null || payload == null) return;
    _pendingPayload = null;
    handler(payload);
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    final data = message.data;
    if (!_notificationsEnabled ||
        (data['type'] == 'announcement' && !_customNotificationsEnabled)) {
      return;
    }
    final title = data['title']?.toString() ?? message.notification?.title;
    final body = data['body']?.toString() ?? message.notification?.body;
    if (title == null || body == null) return;
    await showLocalEvent(
      id:
          data['notificationId']?.toString() ??
          message.messageId ??
          data['announcementId']?.toString() ??
          title,
      type: data['type']?.toString() ?? 'unknown',
      title: title,
      body: body,
      payload: data,
    );
  }

  Future<void> showLocalEvent({
    required String id,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    String? relatedRideId,
  }) async {
    if (!_notificationsEnabled ||
        (type == 'announcement' && !_customNotificationsEnabled)) {
      return;
    }
    await initializeLocalNotifications();
    final eventPayload = <String, dynamic>{
      ...?payload,
      'notificationId': id,
      'type': type,
      'relatedRideId': ?relatedRideId,
    };
    final channel = _channelVariant(
      _baseChannelFor(type),
      _soundEnabled,
      _vibrationEnabled,
    );
    await _local.show(
      id: id.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          sound: _soundEnabled
              ? RawResourceAndroidNotificationSound('notification_sound')
              : null,
          importance: channel.importance,
          priority: channel.importance == Importance.max
              ? Priority.max
              : Priority.high,
          playSound: _soundEnabled,
          enableVibration: _vibrationEnabled,
          vibrationPattern: _vibrationEnabled
              ? Int64List.fromList([0, 1000])
              : null,
          when: DateTime.now().millisecondsSinceEpoch,
          showWhen: true,
          category: AndroidNotificationCategory.message,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: _soundEnabled,
        ),
      ),
      payload: jsonEncode(eventPayload),
    );
  }

  AndroidNotificationChannel _baseChannelFor(String type) => switch (type) {
    'chat_message' => _messagesChannel,
    'friend_request' || 'friend_request_result' => _friendRequestsChannel,
    'destination_reached' => _rideChannel,
    'announcement' => _announcementsChannel,
    _ => _squadChannel,
  };

  AndroidNotificationChannel _channelVariant(
    AndroidNotificationChannel base,
    bool sound,
    bool vibration,
  ) {
    final suffix =
        '${sound ? '' : '_silent'}'
        '${vibration ? '' : '_no_vibration'}';
    return AndroidNotificationChannel(
      '${base.id}$suffix',
      base.name,
      description: base.description,
      importance: base.importance,
      playSound: sound,
      enableVibration: vibration,
      sound: sound
          ? RawResourceAndroidNotificationSound('notification_sound')
          : null,
      vibrationPattern: vibration ? Int64List.fromList([0, 1000]) : null,
    );
  }

  Map<String, dynamic> _decodePayload(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      debugPrint('Ignoring malformed notification navigation payload.');
    }
    return {};
  }

  Future<void> updateToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      final settings = await _messaging.getNotificationSettings();
      final notificationsEnabled =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'announcementNotificationsEnabled': notificationsEnabled,
        }, SetOptions(merge: true));
      }
    } on FirebaseException catch (error) {
      debugPrint('Unable to save notification token (${error.code}).');
    }
  }

  Future<void> removeToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': FieldValue.delete()},
      );
      await _messaging.deleteToken();
    } on FirebaseException catch (error) {
      debugPrint('Unable to remove notification token (${error.code}).');
    }
  }
}

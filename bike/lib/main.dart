import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/rider_model.dart';
import 'providers/squad_provider.dart';
import 'providers/bike_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/ride_tracking_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/squad_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/ride_tracking_screen.dart';
import 'theme/app_theme.dart';
import 'providers/community_provider.dart';
import 'providers/notification_provider.dart';
import 'widgets/community_dialogs.dart';
import 'widgets/profile_photo.dart';
import 'screens/notifications_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/announcements_screen.dart';
import 'providers/announcement_provider.dart';
import 'models/announcement.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/chats_screen.dart';
import 'services/notification_service.dart';
import 'screens/expenses_screen.dart';
import 'screens/bike_brand_selection_screen.dart';
import 'screens/ride_reports_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/group_detail_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService().init();
  try {
    await loadSavedRideExpenses();
  } catch (error, stackTrace) {
    debugPrint('Unable to load saved ride expenses: $error\n$stackTrace');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SquadProvider()),
        ChangeNotifierProvider(create: (_) => BikeProvider()),
        ChangeNotifierProvider(create: (_) => RideSetup()),
        ChangeNotifierProvider(create: (_) => RideTrackingProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
        ChangeNotifierProvider(create: (_) => AppTheme()),
      ],
      child: const BikeSquadApp(),
    ),
  );
}

class BikeSquadApp extends StatelessWidget {
  const BikeSquadApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();

    return MaterialApp(
      title: 'Bike Squad',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: appTheme.themeData,
      home: const SplashScreen(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late final AuthProvider _authProvider;
  Timer? _presenceTimer;
  StreamSubscription<Map<String, String?>>? _destinationSubscription;
  bool _isForeground = true;

  static const _labels = ['Home', 'Map', 'Squad', 'Status', 'Settings'];
  static const _icons = [
    Icons.home_outlined,
    Icons.map_outlined,
    Icons.groups_outlined,
    Icons.bar_chart_outlined,
    Icons.settings_outlined,
  ];
  static const _selectedIcons = [
    Icons.home,
    Icons.map,
    Icons.groups,
    Icons.bar_chart,
    Icons.settings,
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_syncPresence);
    NotificationService().setTapHandler(_openNotification);
    _screens = [
      _HomeScreen(
        onSquadTap: () => setState(() => _selectedIndex = 2),
        onRideStarted: () => setState(() => _selectedIndex = 1),
      ),
      MapTabScreen(onRideEnded: () => setState(() => _selectedIndex = 0)),
      const SquadScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];
    _syncPresence();
    final notifications = context.read<NotificationProvider>();
    _destinationSubscription = context
        .read<RideTrackingProvider>()
        .destinationReachedEvents
        .listen((event) {
          unawaited(
            notifications
                .recordDestinationReached(
                  rideId: event['rideId']!,
                  destinationName: event['destinationName'],
                )
                .catchError((Object error) {
                  debugPrint('Unable to save destination alert: $error');
                }),
          );
        });
  }

  void _syncPresence() {
    _presenceTimer?.cancel();
    final isOnline = _isForeground && _authProvider.currentUser != null;
    NotificationService().setNavigationReady(
      _isForeground && _authProvider.currentUser != null,
    );
    unawaited(_authProvider.setPresence(isOnline));
    if (isOnline) {
      _presenceTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(_authProvider.setPresence(true)),
      );
    }
  }

  void _openNotification(Map<String, dynamic> payload) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || _authProvider.currentUser == null) return;
    final type = payload['type']?.toString();
    if (type == 'announcement') {
      final announcementId = payload['announcementId']?.toString();
      if (announcementId != null && announcementId.isNotEmpty) {
        unawaited(_openAnnouncement(announcementId));
      }
      return;
    }
    final notificationId = payload['notificationId']?.toString();
    if (notificationId != null && notificationId.isNotEmpty) {
      unawaited(
        context
            .read<NotificationProvider>()
            .markRead(notificationId)
            .catchError((Object error) {
              debugPrint('Unable to mark notification as read: $error');
            }),
      );
    }
    if (type == 'destination_reached') {
      navigator.popUntil((route) => route.isFirst);
      if (mounted) setState(() => _selectedIndex = 1);
      return;
    }
    if (type == 'friend_request' || type == 'squad_join_request') {
      navigator.push<void>(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      );
      return;
    }
    final chatId =
        payload['relatedChatId']?.toString() ??
        payload['conversationId']?.toString();
    if (chatId != null && chatId.isNotEmpty) {
      unawaited(_openChat(chatId));
      return;
    }
    final squadId =
        payload['relatedSquadId']?.toString() ?? payload['squadId']?.toString();
    if (squadId != null && squadId.isNotEmpty) {
      unawaited(_openSquad(squadId));
      return;
    }
    navigator.push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  Future<void> _openAnnouncement(String announcementId) async {
    try {
      final document = await FirebaseFirestore.instance
          .collection('announcements')
          .doc(announcementId)
          .get();
      if (!document.exists || !mounted) return;
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AnnouncementDetailsScreen(
            announcement: Announcement.fromMap(document.id, document.data()!),
          ),
        ),
      );
    } on FirebaseException catch (error) {
      debugPrint('Unable to open announcement (${error.code}).');
    }
  }

  Future<void> _openSquad(String squadId) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final squad = context.read<SquadProvider>();
    try {
      await squad.loadJoinedGroup(squadId);
      if (!mounted || appNavigatorKey.currentState == null) return;
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider<SquadProvider>.value(
            value: squad,
            child: GroupDetailScreen(groupId: squadId),
          ),
        ),
      );
    } on FirebaseException catch (error) {
      debugPrint('Unable to open notification squad (${error.code}).');
    }
  }

  Future<void> _openChat(String conversationId) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final participants = List<String>.from(
        data['participants'] as List? ?? const [],
      );
      final currentId = _authProvider.currentUser?.uid;
      final otherId = participants.firstWhere(
        (id) => id != currentId,
        orElse: () => '',
      );
      final names = Map<String, dynamic>.from(
        data['participantNames'] as Map? ?? const {},
      );
      final title = data['kind'] == 'squad'
          ? (data['title'] as String? ?? 'Squad Chat')
          : (names[otherId] as String? ?? 'Chat');
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            title: title,
            subtitle: 'Messages',
            friendUserId: otherId.isEmpty ? null : otherId,
            isDirectChat: data['kind'] != 'squad',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      debugPrint('Unable to open notification chat (${error.code}).');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    _syncPresence();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceTimer?.cancel();
    unawaited(_destinationSubscription?.cancel());
    _authProvider.removeListener(_syncPresence);
    unawaited(_authProvider.setPresence(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.orange, width: 3)),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.blue, width: 2)),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            backgroundColor: AppColors.themedBackground,
            selectedItemColor: AppColors.orange,
            unselectedItemColor: const Color.fromARGB(255, 247, 241, 241),
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: List.generate(
              _labels.length,
              (i) => BottomNavigationBarItem(
                icon: Icon(_icons[i]),
                activeIcon: Icon(_selectedIcons[i]),
                label: _labels[i],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Home Screen ──────────────────────────────────────────────────────────────
class _HomeScreen extends StatelessWidget {
  final VoidCallback? onSquadTap;
  final VoidCallback onRideStarted;

  const _HomeScreen({this.onSquadTap, required this.onRideStarted});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final squad = context.watch<SquadProvider>();
    final tracking = context.watch<RideTrackingProvider>();
    final notifications = context.watch<NotificationProvider>();

    final today = DateTime.now();
    final todayRides = tracking.completedRides
        .where(
          (ride) =>
              ride.endTime.year == today.year &&
              ride.endTime.month == today.month &&
              ride.endTime.day == today.day,
        )
        .toList();
    final todayDistance = todayRides.fold<double>(
      0,
      (sum, ride) => sum + ride.distanceKm,
    );
    final todayDuration = todayRides.fold<Duration>(
      Duration.zero,
      (sum, ride) => sum + ride.totalDuration,
    );
    final todayBreakTime = todayRides.fold<Duration>(
      Duration.zero,
      (sum, ride) => sum + ride.stoppedDuration,
    );

    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: Text(
          'Bike Squad',
          style: TextStyle(color: AppColors.themedText),
        ),
        actions: [
          IconButton(
            tooltip: 'Chats',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const ChatsScreen()),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Announcements',
                    icon: const Icon(Icons.campaign_outlined),
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AnnouncementsScreen(),
                      ),
                    ),
                  ),
                  if (context.watch<AnnouncementProvider>().unreadCount > 0)
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.white, width: 1),
                          ),
                        ),
                        child: SizedBox(width: 10, height: 10),
                      ),
                    ),
                ],
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    ),
                  ),
                  if (notifications.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 10,
                          minHeight: 10,
                        ),
                        padding: notifications.unreadCount > 9
                            ? const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              )
                            : EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: notifications.unreadCount > 9
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          borderRadius: notifications.unreadCount > 9
                              ? BorderRadius.circular(10)
                              : null,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: notifications.unreadCount > 9
                            ? Text(
                                notifications.unreadCount > 99
                                    ? '99+'
                                    : '${notifications.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfilePhoto(
                    photoUrl: currentUser?.photoUrl,
                    photoPath: currentUser?.photoPath,
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: AppColors.themedGrey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentUser?.name ?? 'Rider',
                          style: TextStyle(
                            color: AppColors.themedText,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.filter_alt_outlined, size: 20),
                      color: AppColors.orange,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Quick actions',
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.42,
                children: [
                  _QuickActionCard(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Add Rider',
                    color: const Color(0xFFFFF0EC),
                    onTap: () => showAddRiderDialog(context),
                  ),
                  _QuickActionCard(
                    icon: Icons.two_wheeler_rounded,
                    title: 'Add Bike',
                    color: const Color(0xFFF4F6FF),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => const AddBikeDialog(),
                    ),
                  ),
                  _QuickActionCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Messages',
                    color: const Color(0xFFF5F3FF),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ChatsScreen(),
                      ),
                    ),
                  ),
                  _QuickActionCard(
                    icon: Icons.notifications_active_outlined,
                    title: 'Alerts',
                    color: const Color(0xFFFDF7E8),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF111111),
                      Color(0xFF2A2A2A),
                      Color(0xFF1B1B1B),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Ride ready',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.bolt_rounded,
                          size: 20,
                          color: Color(0xFFFFB74D),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Your next ride is waiting',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _HomeStatChip(
                          icon: Icons.route_rounded,
                          label: '32 km',
                        ),
                        const SizedBox(width: 10),
                        _HomeStatChip(
                          icon: Icons.timer_rounded,
                          label: _formatRideDuration(todayDuration),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => onRideStarted(),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text(
                          'Start ride',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _FeatureTile(
                      icon: Icons.map_outlined,
                      title: 'Map',
                      value: 'Live',
                      onTap: () => onRideStarted(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeatureTile(
                      icon: Icons.groups_rounded,
                      title: 'Squad',
                      value: squad.activeGroup?.name ?? 'Find riders',
                      onTap: onSquadTap ?? () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _FeatureTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Expenses',
                      value: 'Track',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExpensesScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeatureTile(
                      icon: Icons.bar_chart_rounded,
                      title: 'Reports',
                      value: 'Stats',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const RideReportsScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFEDE7E2), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Today',
                          style: TextStyle(
                            color: AppColors.themedText,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${todayRides.length} rides',
                          style: TextStyle(
                            color: AppColors.themedGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (todayRides.isEmpty)
                      Text(
                        'No ride recorded yet. Start a new trip to log your stats.',
                        style: TextStyle(
                          color: AppColors.themedGrey,
                          fontSize: 14,
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _MiniMetric(
                              label: 'Distance',
                              value: '${todayDistance.toStringAsFixed(1)} km',
                            ),
                          ),
                          Expanded(
                            child: _MiniMetric(
                              label: 'Ride time',
                              value: _formatRideDuration(todayDuration),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniMetric(
                              label: 'Break time',
                              value: _formatRideDuration(todayBreakTime),
                            ),
                          ),
                          Expanded(
                            child: _MiniMetric(label: 'Spent', value: 'NA'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: const Color(0xFFFFF2EE),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const RideReportsScreen(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.summarize_outlined,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Generate rider report',
                              style: TextStyle(
                                color: AppColors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.themedGrey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HomeStatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9E1DE), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.orange, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: AppColors.themedGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.themedGrey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: AppColors.themedText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRideDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${duration.inMinutes}m';
}

// ─── Map Tab Screen ─────────────────────────────────────────────────────────
class LegacyMapTabScreen extends StatefulWidget {
  final VoidCallback onRideEnded;

  const LegacyMapTabScreen({super.key, required this.onRideEnded});

  @override
  State<LegacyMapTabScreen> createState() => _LegacyMapTabScreenState();
}

class _LegacyMapTabScreenState extends State<LegacyMapTabScreen> {
  String _modeLabel(RideMode mode) {
    switch (mode) {
      case RideMode.duo:
        return 'Duo Ride';
      case RideMode.squad:
        return 'Squad Ride';
      case RideMode.solo:
        return 'Solo Ride';
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = context.watch<RideSetup>();

    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(title: const Text('Map')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child:
            setup.rideName == null ||
                setup.fromLocation == null ||
                setup.toLocation == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      color: AppColors.themedGrey,
                      size: 66,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No active ride yet',
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Start a ride from the Home tab to see the map here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.themedGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    setup.rideName!,
                    style: TextStyle(
                      color: AppColors.themedText,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.themedCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.blue, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.route, color: AppColors.orange),
                            const SizedBox(width: 10),
                            Text(
                              _modeLabel(setup.rideMode),
                              style: TextStyle(
                                color: AppColors.themedText,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _MapInfoRow(
                          label: 'From',
                          value: setup.fromLocation ?? '-',
                        ),
                        const SizedBox(height: 8),
                        _MapInfoRow(
                          label: 'To',
                          value: setup.toLocation ?? '-',
                        ),
                        if (setup.isGroupRide) ...[
                          const SizedBox(height: 8),
                          _MapInfoRow(
                            label: 'Squad',
                            value: setup.selectedSquadId ?? 'Unknown',
                          ),
                          const SizedBox(height: 8),
                          _MapInfoRow(
                            label: 'Role',
                            value:
                                setup.selectedRole?.displayName ??
                                'Not selected',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: AppColors.themedBackground,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);

                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.themedSurface,
                            title: const Text('End Ride'),
                            content: const Text(
                              'Do you want to end this ride?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('End Ride'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true || !context.mounted) {
                          return;
                        }

                        context.read<RideSetup>().endRide();
                        widget.onRideEnded();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Ride ended successfully'),
                          ),
                        );
                      },
                      child: const Text(
                        'End Ride',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: Icon(
                        Icons.location_pin,
                        size: 120,
                        color: AppColors.orange.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MapInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _MapInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(color: AppColors.themedGrey, fontSize: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.themedText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

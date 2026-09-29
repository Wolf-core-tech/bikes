import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/rider_model.dart';
import 'models/user_model.dart';
import 'providers/squad_provider.dart';
import 'providers/bike_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/ride_tracking_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/ride_name_screen.dart';
import 'screens/squad_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/ride_tracking_screen.dart';
import 'theme/app_theme.dart';
import 'providers/community_provider.dart';
import 'widgets/community_dialogs.dart';
import 'widgets/friend_presence_label.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/chat_screen.dart';
import 'screens/chats_screen.dart';
import 'services/chat_service.dart';
import 'screens/expenses_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SquadProvider()),
        ChangeNotifierProvider(create: (_) => BikeProvider()),
        ChangeNotifierProvider(create: (_) => RideSetup()),
        ChangeNotifierProvider(create: (_) => RideTrackingProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
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
  }

  void _syncPresence() {
    _presenceTimer?.cancel();
    final isOnline = _isForeground && _authProvider.currentUser != null;
    unawaited(_authProvider.setPresence(isOnline));
    if (isOnline) {
      _presenceTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(_authProvider.setPresence(true)),
      );
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
    final community = context.watch<CommunityProvider>();
    final friends = currentUser == null
        ? const <UserModel>[]
        : community.friendsFor(
            currentUser.uid ?? currentUser.email,
            context.watch<AuthProvider>().registeredUsers,
          );
    Future<void> openFriendChat(UserModel friend) async {
      if (friend.uid == null) return;
      try {
        final conversationId = await ChatService().openDirectConversation(
          friend.uid!,
          otherUserName: friend.name,
        );
        if (!context.mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              title: friend.name,
              subtitle: 'Friend',
              friendUserId: friend.uid,
            ),
          ),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open chat: $error')));
      }
    }

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
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Section ──
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.orangeGlow,
                    border: Border.all(
                      color: const Color.fromARGB(255, 187, 17, 31),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.orange,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome ${currentUser?.name ?? 'Rider'}',
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      squad.activeGroup?.name ?? 'No squad yet',
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Top Action: Expenses ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Manage Expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange.withOpacity(0.15),
                  foregroundColor: AppColors.orange,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.orange.withOpacity(0.5), width: 1.5),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Today's Ride Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.themedCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(
                      255,
                      237,
                      190,
                      146,
                    ).withValues(alpha: 0.08),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Ride",
                    style: TextStyle(
                      fontSize: 20,
                      color: AppColors.orange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (todayRides.isEmpty) ...[
                    Text(
                      'No ride recorded today',
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Start a ride to see your ride statistics',
                      style: TextStyle(color: AppColors.themedGrey),
                    ),
                  ] else ...[
                    _RideInfoRow(
                      title: 'Distance',
                      value: '${todayDistance.toStringAsFixed(1)} KM',
                    ),
                    _RideInfoRow(
                      title: 'Ride Time',
                      value: _formatRideDuration(todayDuration),
                    ),
                    _RideInfoRow(
                      title: 'Break Time',
                      value: _formatRideDuration(todayBreakTime),
                    ),
                    const _RideInfoRow(title: 'Spent', value: 'Not recorded'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showAddRiderDialog(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Rider'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Friends',
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (friends.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.themedCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.themedGreyBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No friends yet.',
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add riders to build your riding network.',
                      style: TextStyle(color: AppColors.themedGrey),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.themedCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.themedGreyBorder),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < friends.length; index++) ...[
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.orangeGlow,
                          child: Text(
                            _friendInitials(friends[index].name),
                            style: const TextStyle(color: AppColors.orange),
                          ),
                        ),
                        title: Text(
                          friends[index].name,
                          style: TextStyle(color: AppColors.themedText),
                        ),
                        subtitle: friends[index].uid == null
                            ? const Text('Friend')
                            : FriendPresenceLabel(userId: friends[index].uid!),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Message friend',
                              icon: const Icon(Icons.chat_bubble_outline),
                              color: AppColors.orange,
                              onPressed: () => openFriendChat(friends[index]),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.themedGrey,
                            ),
                          ],
                        ),
                        onTap: () => openFriendChat(friends[index]),
                      ),
                      if (index < friends.length - 1)
                        Divider(
                          height: 1,
                          indent: 68,
                          color: AppColors.themedGreyBorder,
                        ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Color.fromARGB(255, 255, 255, 255),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.3,
              children: [
                _ActionCard(
                  icon: Icons.play_arrow,
                  title: 'Start Ride',
                  iconColor: AppColors.themedText,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RideNameScreen(onRideStarted: onRideStarted),
                      ),
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.groups,
                  title: 'Squad',
                  iconColor: AppColors.themedText,
                  onTap: onSquadTap ?? () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Ride Info Row ─────────────────────────────────────────────────────────────
class _RideInfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _RideInfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: AppColors.themedText, fontSize: 15),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 15,
              fontWeight: FontWeight.w700,
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

String _friendInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

// ─── Action Card ───────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 255, 255),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: iconColor ?? Color.fromARGB(255, 187, 17, 31),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(
                255,
                237,
                190,
                146,
              ).withValues(alpha: 0.08),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor ?? AppColors.white, size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: iconColor ?? AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

                        if (confirmed != true || !mounted) {
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

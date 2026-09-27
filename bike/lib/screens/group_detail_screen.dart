import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/chat_screen.dart';
import '../services/chat_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../models/user_model.dart';
import '../../providers/squad_provider.dart';
import '../../models/rider_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/squad_widgets.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  RiderGroup? _getGroup(SquadProvider squad) {
    try {
      return squad.groups.firstWhere((g) => g.id == widget.groupId);
    } catch (_) {
      return null;
    }
  }

  void _showAddMemberDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.themedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.orange, width: 1.2),
        ),
        title: const Text(
          'Add Rider',
          style: TextStyle(
            color: AppColors.orange,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.themedText),
          decoration: InputDecoration(
            hintText: "Rider's name",
            hintStyle: TextStyle(color: AppColors.themedGrey),
            prefixIcon: const Icon(Icons.person_add, color: AppColors.orange),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.themedGreyBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
            filled: true,
            fillColor: AppColors.themedCard,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.themedGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.themedText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<SquadProvider>().addMember(
                  widget.groupId,
                  ctrl.text.trim(),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Add',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveSquad(
    BuildContext context,
    SquadProvider squad,
    RiderGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.themedSurface,
        title: const Text('Leave Squad?'),
        content: Text('You will lose access to ${group.name} chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final left = await squad.leaveGroup(group.id);
      if (!context.mounted) return;
      if (left) Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to leave squad: $error')));
    }
  }

  void _showRolePickerSheet(
    BuildContext context,
    RiderGroup group,
    Rider rider,
  ) {
    final squad = context.read<SquadProvider>();
    final isCurrentUser = rider.id == squad.currentUserId;
    if (isCurrentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are the group leader — your role cannot be changed.',
          ),
          backgroundColor: AppColors.themedSurface,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.themedSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppColors.orange, width: 1),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.themedGreyBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  RiderAvatar(rider: rider, size: 44, showBadge: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rider.name,
                          style: TextStyle(
                            color: AppColors.themedText,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Assign Position',
                          style: TextStyle(
                            color: AppColors.themedGrey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: AppColors.themedGreyBorder),
              const SizedBox(height: 12),
              // Role options (excluding leader which is reserved for current user)
              ...RiderRole.values
                  .where((r) => r != RiderRole.leader)
                  .map((role) => _roleOption(ctx, squad, group, rider, role)),
            ],
          ),
        );
      },
    );
  }

  Widget _roleOption(
    BuildContext ctx,
    SquadProvider squad,
    RiderGroup group,
    Rider rider,
    RiderRole role,
  ) {
    final isSelected = rider.role == role;
    return InkWell(
      onTap: () {
        squad.assignRole(group.id, rider.id, role);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orangeGlow : AppColors.themedCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.orange : AppColors.themedGreyBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(role.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.displayName,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.orange
                          : AppColors.themedText,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    _roleDescription(role),
                    style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.orange, size: 20),
          ],
        ),
      ),
    );
  }

  String _roleDescription(RiderRole role) {
    switch (role) {
      case RiderRole.leader:
        return 'Commands the group (reserved)';
      case RiderRole.coLeader:
        return 'Leads the front — position: LEAD';
      case RiderRole.guard:
        return 'Flanks after co-leader or before tail — GUARD';
      case RiderRole.midRider:
        return 'Rides in the middle of the pack — MID';
      case RiderRole.tail:
        return 'Closes the formation at the back — TAIL';
    }
  }

  Future<void> _showGroupCallSheet(
    BuildContext context,
    RiderGroup group,
  ) async {
    final meetingUrl = Uri.parse('https://meet.google.com/new?authuser=0');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.themedSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppColors.orange, width: 1),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.themedGreyBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.videocam, color: AppColors.orange, size: 34),
              const SizedBox(height: 12),
              Text(
                'Start Group Call',
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Launch a live online call for ${group.name} so everyone can stay connected while riding.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.themedGrey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.themedCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.themedGreyBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${group.members.length} riders ready to join',
                      style: TextStyle(
                        color: AppColors.themedGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        side: BorderSide(color: AppColors.themedGreyBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final launched = await launchUrl(
                          meetingUrl,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!launched && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Unable to open the call link right now.',
                              ),
                              backgroundColor: AppColors.themedSurface,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.call),
                      label: const Text('Start Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: AppColors.themedText,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadProvider>(
      builder: (context, squad, _) {
        final group = _getGroup(squad);
        if (group == null) {
          return const Scaffold(body: Center(child: Text('Group not found')));
        }
        final isLeader = squad.isCurrentUser(group.leaderId);

        return Scaffold(
          backgroundColor: AppColors.themedBackground,
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              if (!isLeader)
                IconButton(
                  tooltip: 'Leave squad',
                  icon: const Icon(Icons.logout),
                  onPressed: () => _leaveSquad(context, squad, group),
                ),
              IconButton(
                tooltip: 'Group call',
                icon: const Icon(Icons.videocam),
                onPressed: () => _showGroupCallSheet(context, group),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.orange,
              labelColor: AppColors.orange,
              unselectedLabelColor: AppColors.themedGrey,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              tabs: const [
                Tab(text: 'MEMBERS'),
                Tab(text: 'FORMATION'),
                Tab(text: 'CHAT'),
              ],
            ),
          ),
          floatingActionButton: isLeader && _tabController.index == 0
              ? FloatingActionButton(
                  onPressed: () => _showAddMemberDialog(context),
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.themedText,
                  child: const Icon(Icons.person_add),
                )
              : null,
          body: TabBarView(
            controller: _tabController,
            children: [
              _MembersTab(
                group: group,
                isLeader: isLeader,
                currentUserId: squad.currentUserId,
                onRoleTap: (rider) =>
                    _showRolePickerSheet(context, group, rider),
                onRemove: (rider) => squad.removeMember(group.id, rider.id),
              ),
              _FormationTab(group: group),
              _ChatTab(group: group),
            ],
          ),
        );
      },
    );
  }
}

// Extension so we can call isCurrentUser on the provider
extension _SquadExt on SquadProvider {
  bool isCurrentUser(String id) => id == currentUserId;
}

// ─── Members Tab ──────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  final RiderGroup group;
  final bool isLeader;
  final String currentUserId;
  final void Function(Rider) onRoleTap;
  final void Function(Rider) onRemove;

  const _MembersTab({
    required this.group,
    required this.isLeader,
    required this.currentUserId,
    required this.onRoleTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final community = context.watch<CommunityProvider>();
    if (group.members.isEmpty) {
      return Center(
        child: Text(
          'No members yet.',
          style: TextStyle(color: AppColors.themedGrey, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: group.members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final rider = group.members[i];
        final isSelf = rider.id == currentUserId;
        final isFriend =
            !isSelf && community.areFriends(currentUserId, rider.id);
        final isRegisteredRider = auth.registeredUsers.any(
          (user) => user.uid == rider.id,
        );
        return OrangeCard(
          onTap: () => _showRiderProfile(ctx, auth, community, rider, isFriend),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              RiderAvatar(rider: rider, size: 50),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            rider.name,
                            style: TextStyle(
                              color: AppColors.themedText,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orangeGlow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                color: AppColors.orange,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        RoleChip(role: rider.role, compact: true),
                        if (isFriend) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.success,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Friend',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isFriend)
                IconButton(
                  tooltip: 'Message friend',
                  icon: const Icon(Icons.chat_bubble_outline),
                  color: AppColors.orange,
                  onPressed: () => _openDirectChat(ctx, rider),
                )
              else if (!isSelf && isRegisteredRider)
                IconButton(
                  tooltip: 'Add friend',
                  icon: const Icon(Icons.person_add_alt_1),
                  color: AppColors.themedGrey,
                  onPressed: () =>
                      _sendFriendRequest(ctx, auth, community, rider),
                ),
              // Role change button — only leader, and not on self
              if (isLeader && !isSelf) ...[
                IconButton(
                  onPressed: () => onRoleTap(rider),
                  icon: const Icon(
                    Icons.swap_horiz,
                    color: AppColors.orange,
                    size: 22,
                  ),
                  tooltip: 'Change role',
                ),
                IconButton(
                  onPressed: () => _confirmRemove(context, rider),
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: AppColors.danger.withValues(alpha: 0.8),
                    size: 22,
                  ),
                  tooltip: 'Remove rider',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDirectChat(BuildContext context, Rider rider) async {
    try {
      final conversationId = await ChatService().openDirectConversation(
        rider.id,
        otherUserName: rider.name,
      );
      if (!context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            title: rider.name,
            subtitle: 'Friend',
            friendUserId: rider.id,
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

  Future<void> _sendFriendRequest(
    BuildContext context,
    AuthProvider auth,
    CommunityProvider community,
    Rider rider,
  ) async {
    final sender = auth.currentUser;
    UserModel? receiver;
    for (final user in auth.registeredUsers) {
      if (user.uid == rider.id) {
        receiver = user;
        break;
      }
    }
    if (sender == null || receiver == null) return;
    final result = await community.sendFriendRequest(
      sender: sender,
      receiver: receiver,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  Future<void> _showRiderProfile(
    BuildContext context,
    AuthProvider auth,
    CommunityProvider community,
    Rider rider,
    bool isFriend,
  ) async {
    UserModel? profile;
    for (final user in auth.registeredUsers) {
      if (user.uid == rider.id) {
        profile = user;
        break;
      }
    }
    final requestStatus = community.requestStatus(currentUserId, rider.id);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.themedSurface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RiderAvatar(rider: rider, size: 60, showBadge: false),
              const SizedBox(height: 12),
              Text(
                rider.name,
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isFriend ? 'Friend' : 'Squad Member',
                style: TextStyle(color: AppColors.themedGrey),
              ),
              const SizedBox(height: 16),
              if (isFriend)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openDirectChat(context, rider);
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message'),
                )
              else if (profile != null)
                ElevatedButton.icon(
                  onPressed: requestStatus == 'Send Request'
                      ? () async {
                          final sender = auth.currentUser;
                          if (sender == null) return;
                          final result = await community.sendFriendRequest(
                            sender: sender,
                            receiver: profile!,
                          );
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(result)));
                        }
                      : null,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(
                    requestStatus == 'Send Request'
                        ? 'Add Friend'
                        : requestStatus,
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: AppColors.themedSurface,
                      title: Text(rider.name),
                      content: Text(
                        profile?.email ?? rider.role.displayName,
                        style: TextStyle(color: AppColors.themedGrey),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('View Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context, Rider rider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.themedSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.danger.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        title: Text(
          'Remove Rider?',
          style: TextStyle(color: AppColors.themedText),
        ),
        content: Text(
          'Remove ${rider.name} from the group?',
          style: TextStyle(color: AppColors.themedGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.themedGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              onRemove(rider);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Formation Tab ─────────────────────────────────────────────────────────

class _FormationTab extends StatelessWidget {
  final RiderGroup group;

  const _FormationTab({required this.group});

  @override
  Widget build(BuildContext context) {
    final formation = group.formationOrder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Legend
          OrangeCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FORMATION LEGEND',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: RiderRole.values
                      .map((r) => RoleChip(role: r))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Direction arrow
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.themedGreyBorder)),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.orangeGlow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_upward, color: AppColors.orange, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'FRONT OF RIDE',
                      style: TextStyle(
                        color: AppColors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: Divider(color: AppColors.themedGreyBorder)),
            ],
          ),

          const SizedBox(height: 20),

          if (formation.isEmpty)
            Text(
              'No riders in formation yet.',
              style: TextStyle(color: AppColors.themedGrey),
            )
          else
            // Formation grid — 2 per row
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: formation.length,
              itemBuilder: (ctx, i) {
                final rider = formation[i];
                return OrangeCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${i + 1}',
                        style: TextStyle(
                          color: AppColors.themedGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RiderAvatar(rider: rider, size: 60),
                      const SizedBox(height: 10),
                      Text(
                        rider.name.split(' ').first,
                        style: TextStyle(
                          color: AppColors.themedText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      RoleChip(role: rider.role, compact: true),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Tail indicator
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.themedGreyBorder)),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.themedGreyBorder.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.themedGreyBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      color: AppColors.themedGrey,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'BACK OF RIDE',
                      style: TextStyle(
                        color: AppColors.themedGrey,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: Divider(color: AppColors.themedGreyBorder)),
            ],
          ),
        ],
      ),
    );
  }
}

// Chat Tab

class _ChatTab extends StatefulWidget {
  final RiderGroup group;

  const _ChatTab({required this.group});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  late Future<String> _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = ChatService().openSquadConversation(
      squadId: widget.group.id,
      squadName: widget.group.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _conversationId,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Squad chat is available to squad members only.',
              style: TextStyle(color: AppColors.themedGrey),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ChatScreen(
          conversationId: snapshot.data!,
          title: widget.group.name,
          subtitle: 'Group Chat',
          embedded: true,
          isDirectChat: false,
        );
      },
    );
  }
}

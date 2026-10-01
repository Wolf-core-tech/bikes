import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_models.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/friend_presence_label.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final community = context.watch<CommunityProvider>();
    final currentUser = auth.currentUser;
    final currentId =
        currentUser?.uid ?? currentUser?.email.trim().toLowerCase() ?? '';

    final allFriends = currentUser == null
        ? const <UserModel>[]
        : community.friendsFor(
            currentUser.uid ?? currentUser.email,
            auth.registeredUsers,
          );

    final filteredFriends = _searchQuery.isEmpty
        ? allFriends
        : allFriends
            .where(
              (f) =>
                  f.name.toLowerCase().contains(_searchQuery) ||
                  f.email.toLowerCase().contains(_searchQuery),
            )
            .toList();

    final pendingRequests = community.receivedRequests(currentId);
    final pendingCount = pendingRequests.length;

    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Friends'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.orange,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.themedGrey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: 'Friends (${allFriends.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Friends ──────────────────────────────────────────────────
          _FriendsTab(
            friends: filteredFriends,
            allFriendsCount: allFriends.length,
            searchController: _searchController,
            currentId: currentId,
          ),
          // ── Tab 2: Requests ─────────────────────────────────────────────────
          _RequestsTab(
            requests: pendingRequests,
            currentId: currentId,
          ),
        ],
      ),
    );
  }
}

// ─── Friends Tab ──────────────────────────────────────────────────────────────
class _FriendsTab extends StatelessWidget {
  final List<UserModel> friends;
  final int allFriendsCount;
  final TextEditingController searchController;
  final String currentId;

  const _FriendsTab({
    required this.friends,
    required this.allFriendsCount,
    required this.searchController,
    required this.currentId,
  });

  Future<void> _openChat(BuildContext context, UserModel friend) async {
    if (friend.uid == null) return;
    try {
      final conversationId = await ChatService().openDirectConversation(
        friend.uid!,
        otherUserName: friend.name,
      );
      if (!context.mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open chat: $error')),
      );
    }
  }

  Future<void> _unfollowFriend(BuildContext context, UserModel friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.themedCard,
        title: Text(
          'Unfollow ${friend.name}?',
          style: TextStyle(color: AppColors.themedText),
        ),
        content: Text(
          'They will no longer appear in your friends list.',
          style: TextStyle(color: AppColors.themedGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.themedGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              foregroundColor: Colors.red,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await context.read<CommunityProvider>().removeFriend(currentId, friend);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unfollowed ${friend.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search Bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: searchController,
            style: TextStyle(color: AppColors.themedText),
            decoration: InputDecoration(
              hintText: 'Search friends…',
              hintStyle: TextStyle(color: AppColors.themedGrey),
              prefixIcon: Icon(Icons.search, color: AppColors.themedGrey),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, color: AppColors.themedGrey),
                      onPressed: () => searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.themedCard,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.themedGreyBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.orange, width: 1.5),
              ),
            ),
          ),
        ),

        // ── Stats Row ──
        if (allFriendsCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _StatPill(
                  icon: Icons.people,
                  label: '$allFriendsCount Friend${allFriendsCount != 1 ? 's' : ''}',
                ),
              ],
            ),
          ),

        // ── List ──
        Expanded(
          child: friends.isEmpty
              ? _EmptyFriends(hasSearch: searchController.text.isNotEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: friends.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return _FriendCard(
                      friend: friend,
                      onMessage: () => _openChat(context, friend),
                      onUnfollow: () => _unfollowFriend(context, friend),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Friend Card ──────────────────────────────────────────────────────────────
class _FriendCard extends StatelessWidget {
  final UserModel friend;
  final VoidCallback onMessage;
  final VoidCallback onUnfollow;

  const _FriendCard({
    required this.friend,
    required this.onMessage,
    required this.onUnfollow,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.themedCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.themedGreyBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orangeGlow,
                  border: Border.all(color: AppColors.orange, width: 2),
                ),
                child: Center(
                  child: Text(
                    _initials(friend.name),
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Name + presence
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: TextStyle(
                    color: AppColors.themedText,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                if (friend.uid != null)
                  FriendPresenceLabel(userId: friend.uid!)
                else
                  Text(
                    friend.email,
                    style: TextStyle(
                      color: AppColors.themedGrey,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Unfollow (Following) button
          GestureDetector(
            onTap: onUnfollow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.themedGreyBorder,
                ),
              ),
              child: Text(
                'Following',
                style: TextStyle(
                  color: AppColors.themedText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 8),

          // Message button
          GestureDetector(
            onTap: onMessage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.orangeGlow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.orange,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Requests Tab ─────────────────────────────────────────────────────────────
class _RequestsTab extends StatefulWidget {
  final List<FriendRequest> requests;
  final String currentId;

  const _RequestsTab({required this.requests, required this.currentId});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  final Set<String> _busy = {};

  Future<void> _respond(String requestId, bool accept) async {
    setState(() => _busy.add(requestId));
    final message = await context.read<CommunityProvider>().respondToRequest(
          requestId,
          accept,
          widget.currentId,
        );
    if (!mounted) return;
    setState(() => _busy.remove(requestId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: accept ? Colors.green : AppColors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = widget.requests;

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orangeGlow,
                border: Border.all(color: AppColors.orange, width: 1.5),
              ),
              child: const Icon(
                Icons.person_add_alt_1_outlined,
                color: AppColors.orange,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No pending requests',
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When someone sends you a friend request,\nit will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.themedGrey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = requests[index];
        final isBusy = _busy.contains(req.id);
        return _RequestCard(
          request: req,
          isBusy: isBusy,
          onAccept: () => _respond(req.id, true),
          onIgnore: () => _respond(req.id, false),
        );
      },
    );
  }
}

// ─── Request Card ─────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final FriendRequest request;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  const _RequestCard({
    required this.request,
    required this.isBusy,
    required this.onAccept,
    required this.onIgnore,
  });

  String _initials(String name) => name.trim().isEmpty
      ? '?'
      : name
          .trim()
          .split(RegExp(r'\s+'))
          .map((part) => part[0])
          .take(2)
          .join()
          .toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.themedCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.themedGreyBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.orangeGlow,
                  border: Border.all(color: AppColors.orange, width: 2),
                ),
                child: Center(
                  child: Text(
                    _initials(request.senderName),
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name + email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.senderName,
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.senderEmail,
                      style: TextStyle(
                        color: AppColors.themedGrey,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // New badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.orangeGlow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            '${request.senderName} wants to be your riding buddy! 🏍️',
            style: TextStyle(
              color: AppColors.themedGrey,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons
          isBusy
              ? const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.orange,
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onIgnore,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.themedGrey,
                          side: BorderSide(color: AppColors.themedGreyBorder),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Ignore',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text(
                          'Accept',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

// ─── Empty Friends State ──────────────────────────────────────────────────────
class _EmptyFriends extends StatelessWidget {
  final bool hasSearch;
  const _EmptyFriends({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.orangeGlow,
              border: Border.all(color: AppColors.orange, width: 1.5),
            ),
            child: Icon(
              hasSearch ? Icons.search_off : Icons.people_outline,
              color: AppColors.orange,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasSearch ? 'No results found' : 'No friends yet',
            style: TextStyle(
              color: AppColors.themedText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try a different name or email.'
                : 'Send friend requests from the Home screen\nto build your riding network.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.themedGrey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Pill ────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orangeGlow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.orange, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

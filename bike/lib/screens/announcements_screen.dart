import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/announcement.dart';
import '../providers/announcement_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_photo.dart';
import 'announcement_editor_screen.dart';

enum _AnnouncementFilter {
  all,
  upcoming,
  communityNews,
  important,
  past,
  cancelled,
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _scrollController = ScrollController();
  _AnnouncementFilter _filter = _AnnouncementFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 350) {
      unawaited(context.read<AnnouncementProvider>().loadMore());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  List<Announcement> _filtered(List<Announcement> announcements) {
    final now = DateTime.now();
    final filtered = switch (_filter) {
      _AnnouncementFilter.all => announcements,
      _AnnouncementFilter.upcoming =>
        announcements
            .where(
              (item) =>
                  !item.isCancelled &&
                  item.eventDateTime != null &&
                  item.eventDateTime!.isAfter(now) &&
                  (item.category == AnnouncementCategory.ride ||
                      item.category == AnnouncementCategory.meetup),
            )
            .toList(),
      _AnnouncementFilter.communityNews =>
        announcements
            .where(
              (item) => item.category == AnnouncementCategory.communityNews,
            )
            .toList(),
      _AnnouncementFilter.important =>
        announcements
            .where(
              (item) =>
                  item.category == AnnouncementCategory.importantUpdate ||
                  item.category == AnnouncementCategory.emergency,
            )
            .toList(),
      _AnnouncementFilter.past =>
        announcements
            .where(
              (item) =>
                  !item.isCancelled &&
                  item.eventDateTime != null &&
                  item.eventDateTime!.isBefore(now),
            )
            .toList(),
      _AnnouncementFilter.cancelled =>
        announcements.where((item) => item.isCancelled).toList(),
    };
    if (_filter == _AnnouncementFilter.upcoming) {
      filtered.sort(
        (first, second) =>
            first.eventDateTime!.compareTo(second.eventDateTime!),
      );
    }
    return filtered;
  }

  Future<void> _create() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AnnouncementEditorScreen()),
    );
  }

  Future<void> _deleteDraft(Announcement announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete draft?'),
        content: const Text('This draft has not been published.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AnnouncementProvider>().deleteDraft(announcement);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete draft: $error')),
        );
      }
    }
  }

  Future<void> _edit(Announcement announcement) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AnnouncementEditorScreen(announcement: announcement),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnnouncementProvider>();
    final filtered = _filtered(provider.announcements);
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () async {
                try {
                  await provider.markAllRead();
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Unable to mark announcements as read: $error',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Mark read'),
            ),
        ],
      ),
      floatingActionButton: provider.canPublish
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create announcement'),
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
            )
          : null,
      body: provider.isLoading && provider.announcements.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            )
          : RefreshIndicator(
              color: AppColors.orange,
              onRefresh: provider.refresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (provider.error != null)
                    SliverToBoxAdapter(
                      child: _StatusBanner(
                        message:
                            'Some announcements may not be current. Pull down to retry.',
                        icon: Icons.cloud_off_outlined,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 54,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: _AnnouncementFilter.values
                            .map(
                              (filter) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                child: ChoiceChip(
                                  label: Text(_filterLabel(filter)),
                                  selected: filter == _filter,
                                  onSelected: (_) =>
                                      setState(() => _filter = filter),
                                  selectedColor: AppColors.orange,
                                  labelStyle: TextStyle(
                                    color: filter == _filter
                                        ? Colors.white
                                        : AppColors.themedText,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  if (provider.canPublish && provider.drafts.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: _SectionHeading(title: 'Your drafts'),
                    ),
                    SliverList.separated(
                      itemCount: provider.drafts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final draft = provider.drafts[index];
                        return _AnnouncementCard(
                          announcement: draft,
                          unread: false,
                          onTap: () => _edit(draft),
                          draft: true,
                          onDelete: () => _deleteDraft(draft),
                        );
                      },
                    ),
                  ],
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyAnnouncements(filter: _filter),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                      sliver: SliverList.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final announcement = filtered[index];
                          return _AnnouncementCard(
                            announcement: announcement,
                            unread: !provider.isRead(announcement.id),
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => AnnouncementDetailsScreen(
                                  announcement: announcement,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (provider.isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),
    );
  }

  String _filterLabel(_AnnouncementFilter filter) => switch (filter) {
    _AnnouncementFilter.all => 'All',
    _AnnouncementFilter.upcoming => 'Upcoming rides',
    _AnnouncementFilter.communityNews => 'Community news',
    _AnnouncementFilter.important => 'Important',
    _AnnouncementFilter.past => 'Past events',
    _AnnouncementFilter.cancelled => 'Cancelled',
  };
}

class AnnouncementDetailsScreen extends StatefulWidget {
  const AnnouncementDetailsScreen({super.key, required this.announcement});

  final Announcement announcement;

  @override
  State<AnnouncementDetailsScreen> createState() =>
      _AnnouncementDetailsScreenState();
}

class _AnnouncementDetailsScreenState extends State<AnnouncementDetailsScreen> {
  bool _responding = false;
  late Announcement _activeAnnouncement;

  Announcement get announcement => _activeAnnouncement;

  @override
  void initState() {
    super.initState();
    _activeAnnouncement = widget.announcement;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_markRead()));
  }

  Future<void> _markRead() async {
    try {
      await context.read<AnnouncementProvider>().markRead(announcement.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update read status: $error')),
        );
      }
    }
  }

  Future<void> _reloadAnnouncement() async {
    final document = await FirebaseFirestore.instance
        .collection('announcements')
        .doc(announcement.id)
        .get();
    if (document.exists && mounted) {
      setState(
        () => _activeAnnouncement = Announcement.fromMap(
          document.id,
          document.data()!,
        ),
      );
    }
  }

  bool get _supportsRsvp =>
      announcement.category == AnnouncementCategory.ride ||
      announcement.category == AnnouncementCategory.meetup;

  Future<void> _respond(AnnouncementRsvp response) async {
    setState(() => _responding = true);
    try {
      await context.read<AnnouncementProvider>().respond(
        announcement: announcement,
        response: response,
        displayName: context.read<AuthProvider>().currentUser?.name ?? 'Rider',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save your response: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  Future<void> _cancel() async {
    final message = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The announcement will remain visible and riders will be notified.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: message,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Cancellation message (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep event'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel event'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      message.dispose();
      return;
    }
    try {
      await context.read<AnnouncementProvider>().cancel(
        announcement,
        message.text,
      );
      await _reloadAnnouncement();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to cancel event: $error')),
        );
      }
    } finally {
      message.dispose();
    }
  }

  Future<void> _openMap() async {
    final latitude = announcement.latitude;
    final longitude = announcement.longitude;
    if (latitude == null || longitude == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a maps app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnnouncementProvider>();
    final canManage =
        provider.canPublish && provider.userId == announcement.creatorUserId;
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Announcement'),
        actions: [
          if (canManage && !announcement.isCancelled)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  unawaited(
                    Navigator.of(context)
                        .push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => AnnouncementEditorScreen(
                              announcement: announcement,
                            ),
                          ),
                        )
                        .then((_) => _reloadAnnouncement()),
                  );
                } else if (value == 'cancel') {
                  unawaited(_cancel());
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit announcement')),
                PopupMenuItem(value: 'cancel', child: Text('Cancel event')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _StatusPill(announcement: announcement),
          const SizedBox(height: 12),
          Text(
            announcement.title,
            style: TextStyle(
              color: AppColors.themedText,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            announcementCategoryLabel(announcement.category).toUpperCase(),
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          _DetailRow(
            icon: Icons.person_outline,
            label: 'Organized by',
            value: announcement.creatorDisplayName,
          ),
          if (announcement.eventDateTime != null)
            _DetailRow(
              icon: Icons.calendar_month_outlined,
              label: 'Event date and time',
              value:
                  '${_formatWallTime(announcement.eventLocalDateTime, announcement.eventDateTime)} • ${announcement.timeZone}',
            ),
          if (announcement.meetingPlace?.isNotEmpty == true)
            _DetailRow(
              icon: Icons.place_outlined,
              label: 'Meeting place',
              value: announcement.meetingPlace!,
            ),
          if (announcement.meetingAddress?.isNotEmpty == true)
            _DetailRow(
              icon: Icons.directions_outlined,
              label: 'Address',
              value: announcement.meetingAddress!,
            ),
          if (announcement.latitude != null && announcement.longitude != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open meeting point in maps'),
              ),
            ),
          if (announcement.rsvpDeadline != null)
            _DetailRow(
              icon: Icons.event_available_outlined,
              label: 'RSVP by',
              value: _formatWallTime(
                announcement.rsvpDeadlineLocalDateTime,
                announcement.rsvpDeadline,
              ),
            ),
          if (announcement.updatedAt != null &&
              announcement.publishedAt != null &&
              announcement.updatedAt!.isAfter(announcement.publishedAt!))
            _DetailRow(
              icon: Icons.update,
              label: 'Updated',
              value: _formatPublished(announcement.updatedAt!),
            ),
          const SizedBox(height: 20),
          Text(
            announcement.description,
            style: TextStyle(
              color: AppColors.themedText,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (announcement.additionalInstructions?.isNotEmpty == true) ...[
            const SizedBox(height: 18),
            const _SectionHeading(title: 'Additional instructions'),
            const SizedBox(height: 6),
            Text(
              announcement.additionalInstructions!,
              style: TextStyle(color: AppColors.themedGrey, height: 1.5),
            ),
          ],
          if (announcement.isCancelled) ...[
            const SizedBox(height: 20),
            _StatusBanner(
              icon: Icons.event_busy_outlined,
              message: announcement.cancellationMessage?.isNotEmpty == true
                  ? announcement.cancellationMessage!
                  : 'This event has been cancelled.',
            ),
          ],
          if (_supportsRsvp) ...[
            const SizedBox(height: 22),
            const _SectionHeading(title: 'Your attendance'),
            const SizedBox(height: 10),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: provider.watchRsvp(announcement.id),
              builder: (context, snapshot) {
                final current = snapshot.data?.data()?['response'] as String?;
                final expired =
                    announcement.rsvpDeadline != null &&
                    announcement.rsvpDeadline!.isBefore(DateTime.now());
                final disabled =
                    announcement.isCancelled || expired || _responding;
                return Column(
                  children: [
                    for (final option in AnnouncementRsvp.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: disabled ? null : () => _respond(option),
                            icon: Icon(
                              current == announcementRsvpWire(option)
                                  ? Icons.check_circle
                                  : _rsvpIcon(option),
                            ),
                            label: Text(announcementRsvpLabel(option)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  current == announcementRsvpWire(option)
                                  ? Colors.white
                                  : AppColors.themedText,
                              backgroundColor:
                                  current == announcementRsvpWire(option)
                                  ? AppColors.orange
                                  : Colors.transparent,
                              side: BorderSide(
                                color: current == announcementRsvpWire(option)
                                    ? AppColors.orange
                                    : AppColors.themedGreyBorder,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (expired && !announcement.isCancelled)
                      Text(
                        'The RSVP deadline has passed.',
                        style: TextStyle(color: AppColors.themedGrey),
                      ),
                    if (_responding)
                      const LinearProgressIndicator(color: AppColors.orange),
                  ],
                );
              },
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 24),
            const _SectionHeading(title: 'Attendance responses'),
            const SizedBox(height: 10),
            _ResponseSummary(announcement: announcement),
          ],
          const SizedBox(height: 24),
          Text(
            'Published ${_formatPublished(announcement.publishedAt ?? announcement.createdAt ?? DateTime.now())}',
            style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatPublished(DateTime date) =>
      '${date.toLocal().day}/${date.toLocal().month}/${date.toLocal().year} ${date.toLocal().hour.toString().padLeft(2, '0')}:${date.toLocal().minute.toString().padLeft(2, '0')}';

  IconData _rsvpIcon(AnnouncementRsvp response) => switch (response) {
    AnnouncementRsvp.coming => Icons.directions_bike_outlined,
    AnnouncementRsvp.notComing => Icons.close,
    AnnouncementRsvp.unsure => Icons.help_outline,
  };
}

class _ResponseSummary extends StatelessWidget {
  const _ResponseSummary({required this.announcement});
  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AnnouncementProvider>();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: provider.watchResponses(announcement.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _StatusBanner(
            icon: Icons.lock_outline,
            message: 'Attendance summary is unavailable.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          );
        }
        final responses = snapshot.data!.docs;
        final coming = responses
            .where((item) => item.data()['response'] == 'coming')
            .length;
        final notComing = responses
            .where((item) => item.data()['response'] == 'not_coming')
            .length;
        final unsure = responses
            .where((item) => item.data()['response'] == 'unsure')
            .length;
        return FutureBuilder<int>(
          future: provider.eligibleUserCount(),
          builder: (context, eligibleSnapshot) {
            final eligible = eligibleSnapshot.data ?? responses.length;
            final noResponse = (eligible - responses.length).clamp(0, eligible);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CountChip(label: 'Eligible', count: eligible),
                    _CountChip(label: 'Coming', count: coming),
                    _CountChip(label: 'Not coming', count: notComing),
                    _CountChip(label: 'Unsure', count: unsure),
                    _CountChip(label: 'No response', count: noResponse),
                  ],
                ),
                const SizedBox(height: 12),
                for (final item in responses)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ProfilePhoto(
                      photoUrl: null,
                      photoPath: item.data()['photoPath'] as String?,
                      size: 38,
                    ),
                    title: Text(
                      item.data()['displayName'] as String? ?? 'Rider',
                    ),
                    subtitle: Text(
                      _responseLabel(item.data()['response'] as String?),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String _responseLabel(String? value) => switch (value) {
    'coming' => "I'm Coming",
    'not_coming' => 'Not Coming',
    'unsure' => 'Not Sure Yet',
    _ => 'No response',
  };
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text('$label: $count'),
    backgroundColor: AppColors.themedCard,
    side: BorderSide(color: AppColors.themedGreyBorder),
  );
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.unread,
    required this.onTap,
    this.draft = false,
    this.onDelete,
  });

  final Announcement announcement;
  final bool unread;
  final VoidCallback onTap;
  final bool draft;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.themedCard,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    announcementCategoryLabel(
                      announcement.category,
                    ).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                if (unread)
                  const Icon(Icons.circle, size: 10, color: Colors.red),
                if (draft)
                  const _SmallStatus(label: 'DRAFT', color: Colors.blueGrey)
                else
                  _StatusPill(announcement: announcement),
                if (draft && onDelete != null)
                  IconButton(
                    tooltip: 'Delete draft',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 19),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              announcement.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              announcement.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.themedGrey, height: 1.35),
            ),
            if (announcement.eventDateTime != null) ...[
              const SizedBox(height: 10),
              _CardMeta(
                icon: Icons.event_outlined,
                text: _formatWallTime(
                  announcement.eventLocalDateTime,
                  announcement.eventDateTime,
                ),
              ),
            ],
            if (announcement.meetingPlace?.isNotEmpty == true) ...[
              const SizedBox(height: 5),
              _CardMeta(
                icon: Icons.place_outlined,
                text: announcement.meetingPlace!,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'By ${announcement.creatorDisplayName}',
              style: TextStyle(color: AppColors.themedGrey, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.announcement});
  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final updated =
        announcement.updatedAt != null &&
        announcement.publishedAt != null &&
        announcement.updatedAt!.isAfter(announcement.publishedAt!);
    final label = announcement.isCancelled
        ? 'CANCELLED'
        : updated
        ? 'UPDATED'
        : announcement.eventDateTime != null &&
              announcement.eventDateTime!.isBefore(DateTime.now())
        ? 'PAST EVENT'
        : 'PUBLISHED';
    final color = announcement.isCancelled
        ? Colors.redAccent
        : updated
        ? AppColors.orange
        : AppColors.themedGrey;
    return _SmallStatus(label: label, color: color);
  }
}

class _SmallStatus extends StatelessWidget {
  const _SmallStatus({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: AppColors.orange),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
        ),
      ),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: AppColors.themedGrey, fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(color: AppColors.themedText, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Text(
      title,
      style: TextStyle(
        color: AppColors.themedText,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.icon});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.themedCard,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.orange),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: TextStyle(color: AppColors.themedText)),
        ),
      ],
    ),
  );
}

class _EmptyAnnouncements extends StatelessWidget {
  const _EmptyAnnouncements({required this.filter});
  final _AnnouncementFilter filter;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.campaign_outlined,
            size: 56,
            color: AppColors.orange,
          ),
          const SizedBox(height: 12),
          Text(
            filter == _AnnouncementFilter.all
                ? "You're all caught up!"
                : 'No announcements in this category.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.themedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull down to refresh.',
            style: TextStyle(color: AppColors.themedGrey),
          ),
        ],
      ),
    ),
  );
}

String _formatWallTime(String? wallTime, DateTime? fallback) {
  final value = wallTime == null
      ? fallback?.toLocal()
      : DateTime.tryParse(wallTime);
  if (value == null) return '';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} • $hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
}

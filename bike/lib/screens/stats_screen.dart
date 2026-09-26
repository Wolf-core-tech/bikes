import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/squad_provider.dart';
import '../models/ride_stats_model.dart';
import '../models/rider_model.dart';
import '../theme/app_theme.dart';
import 'expenses_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Ride Statistics'),
        backgroundColor: AppColors.themedBackground,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Expenses',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpensesScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.orange,
          labelColor: AppColors.orange,
          unselectedLabelColor: AppColors.themedGrey,
          tabs: const [
            Tab(text: 'Groups Led'),
            Tab(text: 'Ride Stats'),
            Tab(text: 'Leadership'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _GroupsLedTab(),
          const _RideStatsTab(),
          const _LeadershipTab(),
        ],
      ),
    );
  }
}

// ─── Groups Led Tab ───────────────────────────────────────────────────────────
class _GroupsLedTab extends StatelessWidget {
  const _GroupsLedTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadProvider>(
      builder: (context, provider, _) {
        final stats = provider.getRideStatisticsForUser();

        if (stats.totalRidesCompleted == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up_outlined,
                  size: 64,
                  color: AppColors.themedGrey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No rides recorded yet',
                  style: TextStyle(
                    color: AppColors.themedGrey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Stats Card
              _StatsCard(
                title: 'Overall Ride Statistics',
                children: [
                  _StatRow(
                    label: 'Total Rides',
                    value: stats.totalRidesCompleted.toString(),
                    icon: Icons.two_wheeler,
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    label: 'Total Distance',
                    value: '${stats.totalDistanceKm.toStringAsFixed(1)} km',
                    icon: Icons.directions,
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    label: 'Total Duration',
                    value:
                        '${(stats.totalDurationMinutes / 60).toStringAsFixed(1)} hrs',
                    icon: Icons.access_time,
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    label: 'Avg Distance/Ride',
                    value:
                        '${stats.averageDistancePerRide.toStringAsFixed(1)} km',
                    icon: Icons.speed,
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    label: 'Avg Duration/Ride',
                    value: '${stats.averageDurationPerRide} min',
                    icon: Icons.schedule,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Rides Per Group
              const Text(
                'Rides Per Group',
                style: TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...stats.ridesPerGroup.entries.map((entry) {
                final groupStats = stats.statsPerGroup.values.firstWhere(
                  (s) => s.groupName == entry.key,
                  orElse: () => RideStats(
                    groupId: '',
                    groupName: entry.key,
                    ridesCount: 0,
                    totalDistance: 0,
                    totalDuration: 0,
                    roleDistribution: {},
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GroupStatsCard(
                    groupName: entry.key,
                    ridesCount: entry.value,
                    totalDistance: groupStats.totalDistance,
                    averageDistance: groupStats.averageDistance,
                    totalDuration: groupStats.totalDuration,
                    roleDistribution: groupStats.roleDistribution,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ─── Ride Stats Tab ───────────────────────────────────────────────────────────
class _RideStatsTab extends StatelessWidget {
  const _RideStatsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadProvider>(
      builder: (context, provider, _) {
        final groupStats = provider.getRideStatisticsPerGroup();

        if (groupStats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  size: 64,
                  color: AppColors.themedGrey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No group statistics available',
                  style: TextStyle(
                    color: AppColors.themedGrey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: groupStats.map((stat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _GroupDetailCard(stat: stat),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─── Leadership Tab ───────────────────────────────────────────────────────────
class _LeadershipTab extends StatelessWidget {
  const _LeadershipTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadProvider>(
      builder: (context, provider, _) {
        final leadershipStats = provider.getGroupRideLeadership();

        if (leadershipStats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 64,
                  color: AppColors.themedGrey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No leadership data available',
                  style: TextStyle(
                    color: AppColors.themedGrey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: leadershipStats.map((lead) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _LeadershipCard(leadership: lead),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─── Stats Card Widget ────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StatsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.themedCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ─── Stat Row Widget ──────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.orange, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: AppColors.themedText, fontSize: 14),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.orange,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Group Stats Card ─────────────────────────────────────────────────────────
class _GroupStatsCard extends StatelessWidget {
  final String groupName;
  final int ridesCount;
  final double totalDistance;
  final double averageDistance;
  final int totalDuration;
  final Map<RiderRole, int> roleDistribution;

  const _GroupStatsCard({
    required this.groupName,
    required this.ridesCount,
    required this.totalDistance,
    required this.averageDistance,
    required this.totalDuration,
    required this.roleDistribution,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.themedCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.orange.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            groupName,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _MiniStatRow(label: 'Rides', value: ridesCount.toString()),
          const SizedBox(height: 8),
          _MiniStatRow(
            label: 'Distance',
            value: '${totalDistance.toStringAsFixed(1)} km',
          ),
          const SizedBox(height: 8),
          _MiniStatRow(
            label: 'Avg Distance',
            value: '${averageDistance.toStringAsFixed(1)} km',
          ),
          const SizedBox(height: 8),
          _MiniStatRow(
            label: 'Duration',
            value: '${(totalDuration / 60).toStringAsFixed(1)} hrs',
          ),
          if (roleDistribution.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Role Distribution:',
              style: TextStyle(color: AppColors.themedGrey, fontSize: 12),
            ),
            const SizedBox(height: 6),
            ...roleDistribution.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${e.key.displayName}: ${e.value}',
                  style: TextStyle(color: AppColors.themedText, fontSize: 12),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─── Mini Stat Row ───────────────────────────────────────────────────────────
class _MiniStatRow extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.themedGrey, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.themedText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Group Detail Card ────────────────────────────────────────────────────────
class _GroupDetailCard extends StatelessWidget {
  final RideStats stat;

  const _GroupDetailCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.themedCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.groupName,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(
            label: 'Total Rides',
            value: stat.ridesCount.toString(),
            icon: Icons.two_wheeler,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Total Distance',
            value: '${stat.totalDistance.toStringAsFixed(1)} km',
            icon: Icons.directions,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Avg Distance',
            value: '${stat.averageDistance.toStringAsFixed(1)} km',
            icon: Icons.speed,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Total Duration',
            value: '${(stat.totalDuration / 60).toStringAsFixed(1)} hrs',
            icon: Icons.access_time,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Avg Duration',
            value: '${stat.averageDuration} min',
            icon: Icons.schedule,
          ),
          if (stat.roleDistribution.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Role Distribution',
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...stat.roleDistribution.entries.map((entry) {
              final percentage = (entry.value / stat.ridesCount * 100);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${entry.key.emoji} ${entry.key.displayName}',
                          style: TextStyle(
                            color: AppColors.themedText,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            color: AppColors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.themedGrey.withValues(
                          alpha: 0.3,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─── Leadership Card ──────────────────────────────────────────────────────────
class _LeadershipCard extends StatelessWidget {
  final GroupRideLeadership leadership;

  const _LeadershipCard({required this.leadership});

  @override
  Widget build(BuildContext context) {
    final totalRides =
        leadership.totalRidesLed +
        leadership.totalRidesCoLed +
        leadership.totalRidesGuarded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.themedCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            leadership.groupName,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(
            label: 'Leader Role',
            value: '${leadership.totalRidesLed}',
            icon: Icons.emoji_events,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Co-Leader Role',
            value: '${leadership.totalRidesCoLed}',
            icon: Icons.groups_2,
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Guard Role',
            value: '${leadership.totalRidesGuarded}',
            icon: Icons.shield,
          ),
          const SizedBox(height: 20),
          const Text(
            'Role Distribution Breakdown',
            style: TextStyle(
              color: AppColors.orange,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _LeadershipStatBar(
            label: '👑 Leader',
            value: leadership.totalRidesLed,
            total: totalRides,
            percentage: leadership.percentageLed,
          ),
          const SizedBox(height: 12),
          _LeadershipStatBar(
            label: '🥈 Co-Leader',
            value: leadership.totalRidesCoLed,
            total: totalRides,
            percentage: leadership.percentageCoLed,
          ),
          const SizedBox(height: 12),
          _LeadershipStatBar(
            label: '🛡️ Guard',
            value: leadership.totalRidesGuarded,
            total: totalRides,
            percentage: leadership.percentageGuarded,
          ),
        ],
      ),
    );
  }
}

// ─── Leadership Stat Bar ──────────────────────────────────────────────────────
class _LeadershipStatBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final double percentage;

  const _LeadershipStatBar({
    required this.label,
    required this.value,
    required this.total,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$value/$total (${percentage.toStringAsFixed(1)}%)',
              style: const TextStyle(
                color: AppColors.orange,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 12,
            backgroundColor: AppColors.themedGrey.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation(AppColors.orange),
          ),
        ),
      ],
    );
  }
}

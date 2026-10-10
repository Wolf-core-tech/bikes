import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tracked_ride.dart';
import '../providers/ride_tracking_provider.dart';
import '../services/ride_report_service.dart';
import '../theme/app_theme.dart';
import 'expenses_screen.dart';

class RideReportsScreen extends StatelessWidget {
  const RideReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(title: const Text('Generate Report')),
      body: Consumer<RideTrackingProvider>(
        builder: (context, tracking, _) {
          if (tracking.isLoadingHistory) {
            return const Center(child: CircularProgressIndicator());
          }
          if (tracking.completedRides.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 56,
                      color: AppColors.themedGrey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No completed rides yet',
                      style: TextStyle(
                        color: AppColors.themedText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Completed rides will appear here for reporting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.themedGrey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Select a ride to view its report and expenses.',
                style: TextStyle(color: AppColors.themedGrey),
              ),
              const SizedBox(height: 12),
              for (final ride in tracking.completedRides)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RideReportListTile(
                    ride: ride,
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => RideReportDetailScreen(ride: ride),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RideReportListTile extends StatelessWidget {
  const _RideReportListTile({required this.ride, required this.onTap});

  final TrackedRide ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.themedCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.themedGreyBorder),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.orangeGlow,
          child: Icon(Icons.two_wheeler, color: AppColors.orange),
        ),
        title: Text(
          ride.rideName?.trim().isNotEmpty == true
              ? ride.rideName!
              : 'Ride ${ride.id}',
          style: TextStyle(
            color: AppColors.themedText,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${_date(ride.startTime)}  •  ${ride.distanceKm.toStringAsFixed(2)} km  •  ${_duration(ride.totalDuration)}',
          style: TextStyle(color: AppColors.themedGrey),
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.themedGrey),
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';

  String _duration(Duration duration) =>
      '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
}

class RideReportDetailScreen extends StatelessWidget {
  const RideReportDetailScreen({super.key, required this.ride});

  final TrackedRide ride;

  @override
  Widget build(BuildContext context) {
    final rideName = ride.rideName?.trim().isNotEmpty == true
        ? ride.rideName!
        : 'Ride ${ride.id}';
    final expenses = rideExpensesNotifier.value
        .where((expense) => expense.rideName == ride.rideName)
        .expand(
          (expense) => expense.items.map(
            (item) => RideReportExpense(
              description: item.label,
              amount: item.amount,
              location: item.location,
              paymentMethod: item.modeOfPay,
            ),
          ),
        )
        .toList();
    final totalExpenses = expenses.fold<int>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final reportService = RideReportService();

    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(title: const Text('Ride Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.themedCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.themedGreyBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rideName,
                  style: TextStyle(
                    color: AppColors.themedText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _dateTime(ride.startTime),
                  style: TextStyle(color: AppColors.themedGrey),
                ),
                const Divider(height: 28),
                _ReportRow(
                  label: 'Distance',
                  value: '${ride.distanceKm.toStringAsFixed(2)} km',
                ),
                _ReportRow(
                  label: 'Ride duration',
                  value: _duration(ride.totalDuration),
                ),
                _ReportRow(
                  label: 'Stopped time',
                  value: _duration(ride.stoppedDuration),
                ),
                _ReportRow(
                  label: 'Average speed',
                  value: '${ride.averageSpeedKmh.toStringAsFixed(1)} km/h',
                ),
                _ReportRow(
                  label: 'Maximum speed',
                  value: '${ride.maximumSpeedKmh.toStringAsFixed(1)} km/h',
                ),
                _ReportRow(label: 'Stops', value: '${ride.stopCount}'),
                _ReportRow(
                  label: 'GPS points',
                  value: '${ride.points.length}',
                ),
                _ReportRow(
                  label: 'Start location',
                  value: _location(ride.startLatitude, ride.startLongitude),
                ),
                _ReportRow(
                  label: 'End location',
                  value: _location(ride.endLatitude, ride.endLongitude),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ride expenses',
            style: TextStyle(
              color: AppColors.themedText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (expenses.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.themedCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'No expenses recorded for this ride.',
                style: TextStyle(color: AppColors.themedGrey),
              ),
            )
          else ...[
            for (final expense in expenses)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(Icons.receipt_long, color: AppColors.orange),
                title: Text(
                  expense.description,
                  style: TextStyle(color: AppColors.themedText),
                ),
                subtitle: Text(
                  [
                    if (expense.location?.isNotEmpty == true)
                      expense.location!,
                    if (expense.paymentMethod?.isNotEmpty == true)
                      expense.paymentMethod!,
                  ].join(' • '),
                  style: TextStyle(color: AppColors.themedGrey),
                ),
                trailing: Text(
                  formatMoney(expense.amount),
                  style: TextStyle(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ${formatMoney(totalExpenses)}',
                  style: TextStyle(
                    color: AppColors.themedText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final shared = await reportService.downloadReport(
                  ride,
                  rideName: rideName,
                  expenses: expenses,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      shared
                          ? 'Ride report PDF is ready to save or share.'
                          : 'Report export was cancelled or unavailable.',
                    ),
                  ),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not export report: $error')),
                );
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Download report with expenses'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }

  String _dateTime(DateTime value) =>
      '${value.day}/${value.month}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    return hours > 0
        ? '${hours}h ${minutes}m ${seconds}s'
        : '${minutes}m ${seconds}s';
  }

  String _location(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: AppColors.themedGrey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.themedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

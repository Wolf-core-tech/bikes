import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/tracked_ride.dart';

class RideReportExpense {
  final String description;
  final int amount;
  final String? location;
  final String? paymentMethod;

  const RideReportExpense({
    required this.description,
    required this.amount,
    this.location,
    this.paymentMethod,
  });
}

class RideReportService {
  Future<void> printReport(
    TrackedRide ride, {
    String? rideName,
    List<RideReportExpense> expenses = const [],
  }) async {
    await Printing.layoutPdf(
      onLayout: (format) =>
          _buildPdf(format, ride, rideName: rideName, expenses: expenses),
      name: 'ride-${ride.id}.pdf',
    );
  }

  Future<bool> downloadReport(
    TrackedRide ride, {
    String? rideName,
    List<RideReportExpense> expenses = const [],
  }) async {
    final bytes = await _buildPdf(
      PdfPageFormat.a4,
      ride,
      rideName: rideName,
      expenses: expenses,
    );
    return Printing.sharePdf(
      bytes: bytes,
      filename: 'ride-${ride.id}-report.pdf',
      subject: 'Ride report: ${_rideTitle(ride, rideName)}',
    );
  }

  Future<Uint8List> _buildPdf(
    PdfPageFormat format,
    TrackedRide ride, {
    String? rideName,
    required List<RideReportExpense> expenses,
  }) async {
    final document = pw.Document();
    final routeSummary = ride.points
        .take(80)
        .map(
          (point) =>
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        )
        .join('  ->  ');

    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Bike Squad Ride Report - ${_rideTitle(ride, rideName)}'),
          ),
          pw.Text('Ride date: ${_date(ride.startTime)}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Metric', 'Value'],
            data: [
              ['Start', _dateTime(ride.startTime)],
              ['End', _dateTime(ride.endTime)],
              ['Total duration', _duration(ride.totalDuration)],
              ['Total distance', '${ride.distanceKm.toStringAsFixed(2)} km'],
              [
                'Average speed',
                '${ride.averageSpeedKmh.toStringAsFixed(1)} km/h',
              ],
              [
                'Maximum speed',
                '${ride.maximumSpeedKmh.toStringAsFixed(1)} km/h',
              ],
              ['Total stopped time', _duration(ride.stoppedDuration)],
              ['Number of stops', ride.stopCount.toString()],
              [
                'Start location',
                _location(ride.startLatitude, ride.startLongitude),
              ],
              ['End location', _location(ride.endLatitude, ride.endLongitude)],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Expenses', style: pw.Theme.of(context).header3),
          pw.SizedBox(height: 8),
          if (expenses.isEmpty)
            pw.Text('No expenses recorded for this ride.')
          else ...[
            pw.TableHelper.fromTextArray(
              headers: const ['Description', 'Amount', 'Location', 'Payment'],
              data: expenses
                  .map(
                    (expense) => [
                      expense.description,
                      'Rs. ${expense.amount}',
                      expense.location ?? '-',
                      expense.paymentMethod ?? '-',
                    ],
                  )
                  .toList(),
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  'Total expenses: Rs. ${expenses.fold<int>(0, (sum, expense) => sum + expense.amount)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Text('Route representation', style: pw.Theme.of(context).header3),
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500),
            ),
            child: pw.Text(
              routeSummary.isEmpty
                  ? 'No GPS route points recorded.'
                  : routeSummary,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Ride summary: ${ride.points.length} GPS points recorded over ${_duration(ride.totalDuration)}, covering ${ride.distanceKm.toStringAsFixed(2)} km with ${ride.stopCount} stop(s).',
          ),
          pw.SizedBox(height: 12),
          pw.Text('Map data: OpenStreetMap contributors'),
        ],
      ),
    );
    return document.save();
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';

  String _rideTitle(TrackedRide ride, String? rideName) {
    final name = rideName?.trim();
    return name?.isNotEmpty == true ? name! : 'Ride ${ride.id}';
  }

  String _dateTime(DateTime value) =>
      '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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

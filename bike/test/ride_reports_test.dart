import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bikers/models/tracked_ride.dart';
import 'package:bikers/providers/ride_tracking_provider.dart';
import 'package:bikers/screens/expenses_screen.dart';
import 'package:bikers/screens/ride_reports_screen.dart';
import 'package:bikers/services/ride_storage.dart';

void main() {
  tearDown(() {
    rideExpensesNotifier.value = [];
  });

  test('tracked ride JSON keeps its report name and reads older records', () {
    final ride = _testRide();
    final restored = TrackedRide.fromJson(ride.toJson());

    expect(restored.rideName, 'Weekend Trip');
    expect(
      TrackedRide.fromJson({...ride.toJson()}..remove('rideName')).rideName,
      isNull,
    );
  });

  test('ride expenses persist for later reports', () async {
    SharedPreferences.setMockInitialValues({});
    await addExpenseToRide(
      rideName: 'Weekend Trip',
      purpose: 'Petrol',
      amount: 500,
      location: 'Chennai',
      modeOfPay: 'Cash',
    );
    rideExpensesNotifier.value = [];

    await loadSavedRideExpenses();

    expect(rideExpensesNotifier.value.single.rideName, 'Weekend Trip');
    expect(rideExpensesNotifier.value.single.items.single.amount, 500);
    expect(rideExpensesNotifier.value.single.items.single.location, 'Chennai');
    expect(
      rideExpensesNotifier.value.single.items.single.icon,
      Icons.local_gas_station,
    );
  });

  testWidgets('report list opens selected ride with its expenses', (
    WidgetTester tester,
  ) async {
    final ride = _testRide();
    final tracking = RideTrackingProvider(storage: _TestRideStorage([ride]));
    rideExpensesNotifier.value = [
      RideExpense(
        rideName: 'Weekend Trip',
        distance: '10 KM',
        date: '11/10/2026',
        items: const [
          ExpenseItem(
            label: 'Petrol',
            amount: 500,
            icon: Icons.local_gas_station,
            location: 'Chennai',
            modeOfPay: 'Cash',
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<RideTrackingProvider>.value(
        value: tracking,
        child: const MaterialApp(home: RideReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekend Trip'), findsOneWidget);
    await tester.tap(find.text('Weekend Trip'));
    await tester.pumpAndSettle();

    expect(find.text('Ride Report'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Petrol'), findsOneWidget);
    expect(find.text('Rs.500'), findsOneWidget);
    expect(find.text('Total: Rs.500'), findsOneWidget);
    expect(find.text('Download report with expenses'), findsOneWidget);
  });
}

TrackedRide _testRide() {
  final start = DateTime(2026, 10, 11, 8);
  return TrackedRide(
    id: 'ride-1',
    rideName: 'Weekend Trip',
    startTime: start,
    endTime: start.add(const Duration(hours: 2)),
    startLatitude: 13.0827,
    startLongitude: 80.2707,
    endLatitude: 12.9716,
    endLongitude: 77.5946,
    totalDistanceMeters: 100000,
    maximumSpeedMetersPerSecond: 25,
    averageSpeedMetersPerSecond: 15,
    totalDuration: const Duration(hours: 2),
    stoppedDuration: const Duration(minutes: 10),
    stopCount: 2,
    points: const [],
  );
}

class _TestRideStorage extends RideStorage {
  _TestRideStorage(this.rides);

  final List<TrackedRide> rides;

  @override
  Future<List<TrackedRide>> loadRides() async => rides;
}

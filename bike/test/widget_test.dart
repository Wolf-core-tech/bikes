import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bikers/main.dart';
import 'package:bikers/models/bike_model.dart';
import 'package:bikers/providers/auth_provider.dart';
import 'package:bikers/providers/bike_provider.dart';
import 'package:bikers/providers/community_provider.dart';
import 'package:bikers/providers/ride_provider.dart';
import 'package:bikers/providers/ride_tracking_provider.dart';
import 'package:bikers/providers/squad_provider.dart';
import 'package:bikers/screens/group_detail_screen.dart';
import 'package:bikers/screens/settings_screen.dart';
import 'package:bikers/theme/app_theme.dart';
import 'package:bikers/widgets/bike_brand_selector.dart';

void main() {
  testWidgets('Bike Squad app loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SquadProvider()),
          ChangeNotifierProvider(create: (_) => BikeProvider()),
          ChangeNotifierProvider(create: (_) => RideSetup()),
          ChangeNotifierProvider(create: (_) => AppTheme()),
        ],
        child: const BikeSquadApp(),
      ),
    );

    expect(find.byType(BikeSquadApp), findsOneWidget);
    expect(find.text('BIKE SQUAD'), findsWidgets);
  });

  testWidgets('Home shows live-data empty states and only primary actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
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
        child: const MaterialApp(home: MainShell()),
      ),
    );

    expect(find.text('No ride recorded today'), findsOneWidget);
    expect(find.text('No friends yet.'), findsOneWidget);
    expect(find.text('No squad yet'), findsOneWidget);
    expect(find.text('Add Rider'), findsOneWidget);
    expect(find.text('Start Ride'), findsOneWidget);
    expect(find.text('Squad'), findsWidgets);
    expect(find.text('Expenses'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Thunder Hawks'), findsNothing);
  });

  testWidgets('Settings screen exposes a theme switch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SquadProvider()),
          ChangeNotifierProvider(create: (_) => BikeProvider()),
          ChangeNotifierProvider(create: (_) => RideSetup()),
          ChangeNotifierProvider(create: (_) => AppTheme()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('Theme'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('Group detail screen shows the group call entry point', (
    WidgetTester tester,
  ) async {
    final squad = SquadProvider();
    expect(squad.groups, isEmpty);
    final group = squad.createGroup('Test Riders');

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<SquadProvider>.value(value: squad)],
        child: MaterialApp(home: GroupDetailScreen(groupId: group.id)),
      ),
    );

    expect(find.byIcon(Icons.videocam), findsOneWidget);

    await tester.tap(find.byIcon(Icons.videocam));
    await tester.pumpAndSettle();

    expect(find.text('Start Group Call'), findsOneWidget);
  });

  testWidgets('Bike brand selector searches and selects a brand', (
    WidgetTester tester,
  ) async {
    String? selectedBrand;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BikeBrandSelector(
              selectedBrand: selectedBrand,
              onSelected: (brand) => setState(() => selectedBrand = brand),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Search bike brand...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'hon');
    await tester.pumpAndSettle();

    expect(find.text('Honda'), findsOneWidget);
    expect(find.text('Hero MotoCorp'), findsNothing);

    await tester.tap(find.text('Honda'));
    await tester.pumpAndSettle();

    expect(selectedBrand, 'Honda');
    expect(find.text('Honda'), findsOneWidget);

    await tester.tap(find.text('Honda'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'other');
    await tester.pumpAndSettle();

    expect(find.text('Other'), findsOneWidget);
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();

    expect(selectedBrand, 'Other');
    expect(bikeBrandFromRegistrationName(selectedBrand!), BikeBrand.other);
  });
}

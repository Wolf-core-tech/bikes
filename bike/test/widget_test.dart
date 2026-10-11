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
import 'package:bikers/screens/register_screen.dart';
import 'package:bikers/screens/bike_brand_selection_screen.dart';
import 'package:bikers/screens/settings_screen.dart';
import 'package:bikers/theme/app_theme.dart';
import 'package:bikers/widgets/bike_brand_selector.dart';
import 'package:bikers/widgets/bike_brand_logo.dart';

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
    expect(find.text('Add Bike'), findsOneWidget);
    expect(find.text('Start Ride'), findsOneWidget);
    expect(find.text('Squad'), findsWidgets);
    expect(find.text('Generate Report'), findsOneWidget);
    expect(find.text('Expenses'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Thunder Hawks'), findsNothing);

    await tester.ensureVisible(find.text('Add Bike'));
    await tester.tap(find.text('Add Bike'));
    await tester.pumpAndSettle();
    expect(find.text('Add Your Bike'), findsOneWidget);

    final licensePlateField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'e.g., TN-01-XX-0001',
    );
    await tester.ensureVisible(licensePlateField);
    await tester.enterText(licensePlateField, 'tn-01-ab-1234');
    expect(find.text('TN-01-AB-1234'), findsOneWidget);
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
    expect(find.text('Bikes theme'), findsNothing);
    expect(find.byType(Switch), findsOneWidget);

    final appTheme = tester
        .element(find.byType(SettingsScreen))
        .read<AppTheme>();
    expect(appTheme.isDarkMode, isFalse);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(appTheme.isDarkMode, isTrue);
    expect(AppColors.themedBackground, BikesColors.black);
    expect(AppColors.themedSurface, BikesColors.charcoal);
    expect(AppColors.themedText, BikesColors.white);
    expect(AppColors.themedGrey, BikesColors.silver);
    expect(appTheme.themeData.colorScheme.primary, BikesColors.racingRed);
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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/brand/honda.png',
      ),
      findsOneWidget,
    );

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

  testWidgets('Yamaha model selection fills its engine capacity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => BikeProvider()),
          ChangeNotifierProvider(create: (_) => AppTheme()),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );

    await tester.ensureVisible(find.text("Don't have bike"));
    await tester.tap(find.text("Don't have bike"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Have bike'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Search bike brand...'));
    await tester.tap(find.text('Search bike brand...'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Yamaha');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yamaha').last);
    await tester.pumpAndSettle();

    final modelDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(modelDropdown);
    await tester.tap(modelDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('R15M').last);
    await tester.pumpAndSettle();

    final engineCcField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Engine CC *',
    );
    expect(tester.widget<TextField>(engineCcField).controller?.text, '155');
  });

  testWidgets('Add Bike Yamaha model selection fills engine capacity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BikeProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AddBikeDialog(),
                  ),
                  child: const Text('Open Add Bike'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Add Bike'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tap to select brand'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Yamaha');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yamaha Motor India'));
    await tester.pumpAndSettle();

    final modelDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(modelDropdown);
    await tester.tap(modelDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('R15M').last);
    await tester.pumpAndSettle();

    final engineCcField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'e.g., 350',
    );
    final engineCc = tester.widget<TextField>(engineCcField);
    expect(engineCc.controller?.text, '155');
    expect(engineCc.readOnly, isTrue);
  });

  testWidgets('Bike brand logos render in 40dp bounds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: BikeBrandLogo(brand: BikeBrand.yamahaMotorIndia)),
        ),
      ),
    );

    expect(tester.getSize(find.byType(BikeBrandLogo)), const Size(40, 40));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/brand/YAMAHA.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Bike brands with supplied logos use their image assets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BikeBrandLogo(brand: BikeBrand.hondaMotorcycleScoterIndia),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(BikeBrandLogo)), const Size(40, 40));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/brand/honda.png',
      ),
      findsOneWidget,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bikers/providers/auth_provider.dart';
import 'package:bikers/providers/bike_provider.dart';
import 'package:bikers/screens/profile_screen.dart';
import 'package:bikers/widgets/profile_photo.dart';

void main() {
  testWidgets('profile edit dialog lets a rider change their photo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => BikeProvider()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.ensureVisible(find.text('Edit Profile'));
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Change photo'), findsOneWidget);
    expect(find.byType(ProfilePhoto), findsNWidgets(2));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bikers/providers/auth_provider.dart';
import 'package:bikers/screens/splash_screen.dart';

void main() {
  testWidgets('splash navigates to sign in after its animation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _SignedOutAuthProvider(),
        child: const MaterialApp(home: SplashScreen()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 4500));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets(
    'disposing splash during its sequence does not use disposed animations',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 4));

      expect(tester.takeException(), isNull);
    },
  );
}

class _SignedOutAuthProvider extends AuthProvider {
  @override
  Future<bool> checkLoginStatus() async => false;
}

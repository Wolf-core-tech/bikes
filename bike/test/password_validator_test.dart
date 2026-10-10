import 'package:flutter_test/flutter_test.dart';
import 'package:bikers/utils/password_validator.dart';

void main() {
  group('validatePassword', () {
    test(
      'accepts passwords with eight characters, uppercase, and a number',
      () {
        expect(validatePassword('Rider123'), isNull);
      },
    );

    test('requires at least eight characters', () {
      expect(
        validatePassword('BikeA1'),
        'Password must be at least 8 characters long.',
      );
    });

    test('requires an uppercase letter', () {
      expect(
        validatePassword('rider123'),
        'Password must include at least one uppercase letter.',
      );
    });

    test('requires a number', () {
      expect(
        validatePassword('RiderBike'),
        'Password must include at least one number.',
      );
    });
  });

}

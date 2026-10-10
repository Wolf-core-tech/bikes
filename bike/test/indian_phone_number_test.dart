import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bikers/utils/indian_phone_number.dart';

void main() {
  group('IndianPhoneNumberFormatter', () {
    final formatter = IndianPhoneNumberFormatter();

    test('keeps only the first ten digits', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(
          text: '98a76543210',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );

      expect(result.text, '9876543210');
      expect(result.selection.extentOffset, 10);
    });

    test('adds the country code for storage and validates ten digits', () {
      expect(isValidIndianPhoneNumber('9876543210'), isTrue);
      expect(isValidIndianPhoneNumber('987654321'), isFalse);
      expect(toIndianPhoneNumber('9876543210'), '+919876543210');
      expect(indianPhoneNumberDigits('+919876543210'), '9876543210');
    });
  });
}

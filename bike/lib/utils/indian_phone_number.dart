import 'package:flutter/services.dart';

class IndianPhoneNumberFormatter extends TextInputFormatter {
  static const maxDigits = 10;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limitedDigits = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;
    final digitsBeforeCursor = newValue.text
        .substring(0, newValue.selection.extentOffset.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    return TextEditingValue(
      text: limitedDigits,
      selection: TextSelection.collapsed(
        offset: digitsBeforeCursor.clamp(0, limitedDigits.length),
      ),
      composing: TextRange.empty,
    );
  }
}

bool isValidIndianPhoneNumber(String phoneNumber) =>
    RegExp(r'^[0-9]{10}$').hasMatch(phoneNumber);

String toIndianPhoneNumber(String phoneNumber) => '+91$phoneNumber';

String indianPhoneNumberDigits(String phoneNumber) {
  final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.startsWith('91') && digits.length == 12
      ? digits.substring(2)
      : digits;
}

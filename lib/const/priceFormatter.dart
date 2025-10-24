import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class Priceformatter extends TextInputFormatter {
  final NumberFormat formatter = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 입력값이 비어있으면 그대로
    if (newValue.text.isEmpty) return newValue;

    // 숫자만 추출
    String numericString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // 숫자 포맷
    String formatted = formatter.format(int.parse(numericString));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

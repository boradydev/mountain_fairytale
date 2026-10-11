import 'package:flutter/services.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';

class CarNumberInputFormatter extends TextInputFormatter {
  const CarNumberInputFormatter();

  bool _isLetter(String value) => 'АВЕКМНОРСТУХ'.contains(value);
  bool _isDigit(String value) =>
      value.codeUnitAt(0) >= 48 && value.codeUnitAt(0) <= 57;

  String _filter(String value) {
    final normalized = canonicalCarNumber(value);
    final result = StringBuffer();
    for (final character in normalized.split('')) {
      final position = result.length;
      final allowed = switch (position) {
        0 => _isLetter(character),
        1 || 2 || 3 => _isDigit(character),
        4 || 5 => _isLetter(character),
        6 || 7 || 8 => _isDigit(character),
        _ => false,
      };
      if (allowed) result.write(character);
    }
    return result.toString();
  }

  int _displayOffset(int payloadOffset, String text) {
    if (payloadOffset <= 6 || text.length <= 6) return payloadOffset;
    return payloadOffset + 1;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final payload = _filter(newValue.text);
    final formatted = formatCarNumber(payload);
    final rawOffset = newValue.selection.baseOffset
        .clamp(0, newValue.text.length)
        .toInt();
    final typedBeforeCaret = _filter(newValue.text.substring(0, rawOffset))
        .length;
    final offset = _displayOffset(
      typedBeforeCaret,
      formatted,
    ).clamp(0, formatted.length).toInt();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }
}

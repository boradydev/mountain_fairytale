import 'package:flutter/services.dart';

/// Russian numbers: +7 999 123 45 67; API representation: +79991234567.
class RussianPhoneInputFormatter extends TextInputFormatter {
  const RussianPhoneInputFormatter();

  static String nationalDigits(String text) {
    var digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.trimLeft().startsWith('+7') ||
        (digits.length == 11 &&
            (digits.startsWith('7') || digits.startsWith('8')))) {
      digits = digits.substring(1);
    }
    return digits.length > 10 ? digits.substring(0, 10) : digits;
  }

  static String format(String text) => _formatDigits(nationalDigits(text));
  static String toApiPhone(String text) => '+7${nationalDigits(text)}';
  static bool isComplete(String text) => nationalDigits(text).length == 10;

  static String _formatDigits(String digits) {
    final groups = <String>[];
    var start = 0;
    for (final size in [3, 3, 2, 2]) {
      if (start >= digits.length) break;
      final end = (start + size).clamp(0, digits.length);
      groups.add(digits.substring(start, end));
      start = end;
    }
    return '+7 ${groups.join(' ')}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var digits = nationalDigits(newValue.text);
    final rawCursor = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    var before = nationalDigits(newValue.text.substring(0, rawCursor)).length;
    // Backspace over a separator deletes the preceding digit, too.
    if (newValue.text.length < oldValue.text.length &&
        digits == nationalDigits(oldValue.text) &&
        oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        rawCursor < oldValue.selection.extentOffset &&
        before > 0) {
      digits = digits.substring(0, before - 1) + digits.substring(before);
      before--;
    }
    final formatted = _formatDigits(digits);
    var cursor = 3;
    var seen = 0;
    while (cursor < formatted.length && seen < before) {
      if (RegExp(r'[0-9]').hasMatch(formatted[cursor])) seen++;
      cursor++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}

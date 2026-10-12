import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/shared/widgets/russian_phone_input_formatter.dart';

void main() {
  const formatter = RussianPhoneInputFormatter();
  TextEditingValue edit(String text, {int? cursor}) =>
      formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor ?? text.length),
        ),
      );

  test(
    'adds +7 and groups national, international and domestic pasted numbers',
    () {
      for (final text in [
        '9123456789',
        '+7 (912) 345-67-89',
        '8 912 345 67 89',
        '79123456789',
      ]) {
        expect(edit(text).text, '+7 912 345 67 89');
        expect(
          RussianPhoneInputFormatter.toApiPhone(edit(text).text),
          '+79123456789',
        );
      }
      expect(edit('').text, '+7 ');
      expect(edit('9123').text, '+7 912 3');
    },
  );

  test(
    'keeps cursor near inserted digits and supports backspace across spaces',
    () {
      final inserted = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '+7 912 345 67 89',
          selection: TextSelection.collapsed(offset: 8),
        ),
        const TextEditingValue(
          text: '+7 912 305 67 89',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );
      expect(inserted.text, '+7 912 305 67 89');
      expect(inserted.selection.extentOffset, 9);
      final deleted = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '+7 912 345',
          selection: TextSelection.collapsed(offset: 7),
        ),
        const TextEditingValue(
          text: '+7 912345',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      expect(deleted.text, '+7 913 45');
      expect(deleted.selection.extentOffset, 5);
    },
  );

  test(
    'protects prefix, limits national digits and validates complete numbers',
    () {
      expect(edit('123456789012345').text, '+7 123 456 78 90');
      expect(edit('+').text, '+7 ');
      expect(RussianPhoneInputFormatter.isComplete('+7 '), isFalse);
      expect(RussianPhoneInputFormatter.isComplete('+7 912 345'), isFalse);
      expect(RussianPhoneInputFormatter.isComplete('+7 912 345 67 89'), isTrue);
      expect(edit('+7 912', cursor: 0).selection.extentOffset, 3);
    },
  );
}

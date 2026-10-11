import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';
import 'package:mountain_fairytale/features/cars/ui/car_number_input_formatter.dart';

void main() {
  const formatter = CarNumberInputFormatter();

  test('formats a Russian registration number while typing', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: 'a123kx126',
        selection: TextSelection.collapsed(offset: 9),
      ),
    );

    expect(result.text, 'А123КХ 126');
    expect(result.selection.baseOffset, result.text.length);
    expect(canonicalCarNumber(result.text), 'А123КХ126');
    expect(isValidCarNumber(result.text), isTrue);
  });

  test('filters symbols that do not fit the current position', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: 'А12-3КХ 126RUS',
        selection: TextSelection.collapsed(offset: 14),
      ),
    );

    expect(result.text, 'А123КХ 126');
  });
}

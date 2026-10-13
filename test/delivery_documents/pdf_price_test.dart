import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_route/services/route_sheet_pdf_builder.dart';

void main() {
  test('PDF unit price preserves sub-cent precision without changing regular currency formatting', () {
    expect(formatSavedUnitPrice(1.005), '1.005');
    expect(formatSavedUnitPrice(2.675), '2.675');
    expect(formatSavedUnitPrice(1.0049999999999997), '1.0049999999999997');
    expect(formatSavedUnitPrice(100), '100.00');
    expect(formatSavedUnitPrice(1.2), '1.20');
    expect(formatSavedUnitPrice(0), '0.00');
  });
}

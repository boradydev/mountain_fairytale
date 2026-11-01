import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_task_item_model.dart';
import 'package:mountain_fairytale/features/delivery_route/data/route_point_model.dart';
import 'package:mountain_fairytale/features/delivery_route/services/route_sheet_pdf_builder.dart';
import 'package:pdfrx/pdfrx.dart';

Future<String> _printedText(RoutePoint point) async {
  final bytes = await RouteSheetPdfBuilder().build(
    DeliveryRouteSheet(
      date: DateTime(2026, 11, 1),
      driverName: 'Водитель',
      carId: 'car',
      carModelAndNumber: 'Газель А123АА',
      startMileage: 100,
      points: [point],
    ),
  );
  final document = await PdfDocument.openData(bytes);
  try {
    final text = StringBuffer();
    for (final page in document.pages) {
      text.writeln((await page.loadText())!.fullText);
    }
    return text.toString().replaceAll(RegExp(r'\s+'), ' ');
  } finally {
    await document.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(pdfrxInitialize);

  for (final savedPayment in ['Наличные', null]) {
    test(
      'actual PDF prints document payment $savedPayment and client details once',
      () async {
        const details = 'Вход со двора. Позвонить перед доставкой.';
        final point = RoutePoint(
          pointId: 'point',
          clientId: 'client',
          clientName: 'Клиент',
          address: 'Горная, 10 — $details',
          clientAddress: 'Горная, 10',
          deliveryDetails: details,
          phone: '123',
          salesRepresentative: '',
          paymentMethodId: 'sbp',
          paymentMethod: 'СБП',
          documentPaymentMethodId: savedPayment == null ? null : 'cash',
          documentPaymentMethodName: savedPayment,
          items: const [
            DeliveryTaskItem(
              productId: 'water',
              productName: 'Вода',
              quantity: 2,
              price: 350,
            ),
          ],
        );
        final text = await _printedText(point);
        expect(text, contains('Форма оплаты: ${savedPayment ?? 'Не указана'}'));
        expect(text, isNot(contains('СБП')));
        expect(text, contains('Адрес: Горная, 10'));
        expect(text, contains('Доп: $details'));
        expect(RegExp(RegExp.escape(details)).allMatches(text).length, 1);
        expect(text, isNot(contains('Горная, 10 —')));
      },
    );
  }

  test(
    'PDF supports old responses and omits an empty additional-information line',
    () async {
      final point = RoutePoint.fromJson({
        'pointId': 'point',
        'clientId': 'client',
        'clientName': 'Клиент',
        'address': 'Старый адрес с примечанием',
        'phone': '123',
        'defaultPaymentMethodName': 'СБП',
        'items': [],
      });
      final text = await _printedText(point);
      expect(text, contains('Адрес: Старый адрес с примечанием'));
      expect(text, contains('Форма оплаты: Не указана'));
      expect(text, isNot(contains('Доп. информация:')));
      expect(text, isNot(contains('СБП')));
    },
  );
}

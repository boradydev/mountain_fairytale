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

  test('PDF preserves unsuccessful order and reason but excludes its sum from route total', () async {
    final text = await _printedText(
      const RoutePoint(
        clientId: 'client',
        clientName: 'Клиент',
        address: 'Адрес',
        phone: '123',
        salesRepresentative: '',
        isDelivered: false,
        nonDeliveryReason: 'Закрыт магазин',
        items: [
          DeliveryTaskItem(
            productId: 'water',
            productName: 'Вода',
            quantity: 2,
            price: 350,
          ),
        ],
      ),
    );
    expect(text, contains('НЕ ДОСТАВЛЕНО: Закрыт магазин'));
    expect(text, contains('700.00'));
    expect(text, isNot(contains('Не включено в итог')));
    expect(text, contains('Вода'));
    expect(text, contains('0.00'));
  });

  test(
    'PDF prints free-price item with its driver note and saved price',
    () async {
      final text = await _printedText(
        const RoutePoint(
          clientId: 'client',
          clientName: 'Клиент',
          address: 'Адрес',
          phone: '123',
          salesRepresentative: '',
          items: [
            DeliveryTaskItem(
              productId: 'service',
              productName: 'Настройка',
              quantity: 1,
              price: 75,
              isFreePrice: true,
              driverNote: 'Забрать кулер',
            ),
          ],
        ),
      );

      expect(text, contains('Настройка'));
      expect(text, contains('75.00'));
      expect(text, contains('Уточнение: Забрать кулер'));
    },
  );

  test(
    'warehouse load summary excludes all free-price rows',
    () async {
      final text = await _printedText(
        const RoutePoint(
          clientId: 'client',
          clientName: 'Клиент',
          address: 'Адрес',
          phone: '123',
          salesRepresentative: '',
          items: [
            DeliveryTaskItem(
              productId: 'water',
              productName: 'Бесплатная вода',
              quantity: 2,
              price: 0,
            ),
            DeliveryTaskItem(
              productId: 'service-zero',
              productName: 'Услуга без цены',
              quantity: 3,
              price: 0,
              isFreePrice: true,
            ),
            DeliveryTaskItem(
              productId: 'service-priced',
              productName: 'Оценённая услуга',
              quantity: 4,
              price: 25,
              isFreePrice: true,
            ),
          ],
        ),
      );

      int occurrences(String value) =>
          RegExp(RegExp.escape(value)).allMatches(text).length;

      expect(occurrences('Бесплатная вода'), 2);
      expect(occurrences('Услуга без цены'), 1);
      expect(occurrences('Оценённая услуга'), 1);
      expect(text, contains('ЗАГРУЗИТЬ СО СКЛАДА'));
      expect(text, isNot(contains('ЗАГРУЗИТЬ В АВТОМОБИЛЬ')));
    },
  );

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

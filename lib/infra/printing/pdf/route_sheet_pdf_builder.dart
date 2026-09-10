import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class RouteSheetPdfBuilder {
  static const _fontPath = 'assets/fonts/NotoSans-Regular.ttf';
  static const _fontBoldPath = 'assets/fonts/NotoSans-Bold.ttf';

  Future<Uint8List> build(DeliveryRouteSheet sheet) async {
    final regularFont = pw.Font.ttf(await rootBundle.load(_fontPath));

    final boldFont = pw.Font.ttf(await rootBundle.load(_fontBoldPath));

    final pdf = pw.Document();

    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _buildHeader(sheet),
          pw.SizedBox(height: 18),
          _buildRouteInfo(sheet),
          pw.SizedBox(height: 20),
          _buildPointsTable(sheet),
          pw.SizedBox(height: 18),
          _buildTotal(sheet),
          pw.SizedBox(height: 30),
          _buildSignatures(),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(DeliveryRouteSheet sheet) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(color: PdfColors.black),
          children: [
            pw.TextSpan(
              text: 'МАРШРУТНЫЙ ЛИСТ ',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(
              text: 'от ${_formatDate(sheet.date)}',
              style: pw.TextStyle(fontSize: 13,
                  fontWeight: pw.FontWeight.normal,
                  color: PdfColors.grey800),
            ),
          ],
        ),
      ),
    );
  }


  pw.Widget _buildRouteInfo(DeliveryRouteSheet sheet) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
      ),
      child: pw.Column(
        children: [
          _infoRow('Водитель', sheet.driverName),
          _infoRow('Автомобиль', sheet.carModelAndNumber),
          _infoRow(
            'Пробег на начало',
            '${_formatNumber(sheet.startMileage)} км',
          ),
          _infoRow(
            'Пробег на конец',
            sheet.endMileage == null
                ? '________________'
                : '${_formatNumber(sheet.endMileage!)} км',
          ),
        ],
      ),
    );
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _buildPointsTable(DeliveryRouteSheet sheet) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(20), // Номер клиента
        1: pw.FlexColumnWidth(2.5), // Информация о клиенте
        2: pw.FlexColumnWidth(4.5), // Зона под вложенную таблицу "Задание"
        3: pw.FixedColumnWidth(50), // Итоговая сумма по клиенту
      },
      children: [
        // Главная шапка таблицы
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tableHeader('#'),
            _tableHeader('Информация о клиенте'),
            _tableHeader('Задание'),
            _tableHeader('Итого'),
          ],
        ),
        // Строки с данными клиентов
        ...sheet.points.asMap().entries.map((entry) {
          final index = entry.key;
          final point = entry.value;

          return pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.full,
            // Чтобы сетка внутри не съезжала
            children: [
              _tableCell('${index + 1}', align: pw.TextAlign.center),
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerLeft,
                // Выравнивание по вертикали и левому краю
                child: pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(
                        fontSize: 7.5, color: PdfColors.black),
                    children: [
                      pw.TextSpan(text: 'Клиент: '),
                      pw.TextSpan(text: '${point.clientName}\n',
                          style: pw.TextStyle(fontWeight: pw.FontWeight
                              .bold)),
                      pw.TextSpan(text: 'Адрес: '),
                      pw.TextSpan(
                        text: '${point.address}\n', style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold
                      ),
                      ),
                      pw.TextSpan(text: 'Тел: '),
                      pw.TextSpan(text: '${point.phone}\n', style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold
                      ),
                      ),
                      const pw.TextSpan(text: 'Форма оплаты: '),
                      pw.TextSpan(
                        text: point.paymentMethod,
                        style: pw.TextStyle(fontWeight: pw.FontWeight
                            .bold), // ДЕЛАЕМ ЖИРНЫМ
                      ),
                    ],
                  ),
                ),
              ),
              // Сюда передаем наш список продуктов, он разложится в красивую мини-таблицу
              _buildItemsCell(point.items),
              _tableCell(
                '${point.totalAmount.toStringAsFixed(2)} ₽',
                align: pw.TextAlign.center,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildItemsCell(List<dynamic> items) {
    return pw.Table(
      // Внутренние границы между колонками продуктов
      border: const pw.TableBorder(
        verticalInside: pw.BorderSide(color: PdfColors.grey400, width: 0.4),
        horizontalInside: pw.BorderSide(color: PdfColors.grey400, width: 0.4),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(20), // # продукта
        1: pw.FlexColumnWidth(3.0), // Продукция
        2: pw.FixedColumnWidth(45), // Кол-во
        3: pw.FixedColumnWidth(45), // Цена
        4: pw.FixedColumnWidth(50), // Сумма
      },
      children: [
        // Шапка для продуктов (внутри ячейки Задание)
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeader('#'),
            _tableHeader('Продукция'),
            _tableHeader('Кол-во'),
            _tableHeader('Цена'),
            _tableHeader('Сумма'),
          ],
        ),
        // Строки самих продуктов
        ...items
            .asMap()
            .entries
            .map((itemEntry) {
          final subIndex = itemEntry.key;
          final item = itemEntry.value;

          return pw.TableRow(
            children: [
              _tableCell('${subIndex + 1}', align: pw.TextAlign.center),
              _tableCell(item.productName),
              _tableCell('${item.quantity}', align: pw.TextAlign.center),
              _tableCell('${item.price.toStringAsFixed(2)} ₽',
                  align: pw.TextAlign.right),
              _tableCell('${item.amount.toStringAsFixed(2)} ₽',
                  align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }


  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    // Мапим pw.TextAlign в соответствующий pw.Alignment для контейнера
    final containerAlignment = switch (align) {
      pw.TextAlign.left => pw.Alignment.centerLeft,
      pw.TextAlign.right => pw.Alignment.centerRight,
      pw.TextAlign.center => pw.Alignment.center,
      _ => pw.Alignment.centerLeft,
    };

    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: containerAlignment,
      // Выравнивает текст по вертикали и горизонтали внутри ячейки
      child: pw.Text(
        text,
        textAlign: align, // Сохраняем горизонтальный текст-элайн
        style: const pw.TextStyle(fontSize: 7.5),
      ),
    );
  }


  pw.Widget _buildTotal(DeliveryRouteSheet sheet) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(
          'ИТОГО ПО МАРШРУТУ: ',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '${sheet.grandTotal.toStringAsFixed(2)} ₽',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildSignatures() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Водитель: __________________________'),
        pw.Text('Ответственный: ______________________'),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(0);
  }
}

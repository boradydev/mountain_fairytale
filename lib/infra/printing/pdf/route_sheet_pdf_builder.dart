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
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'МАРШРУТНЫЙ ЛИСТ',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'от ${_formatDate(sheet.date)}',
          style: const pw.TextStyle(fontSize: 11),
        ),
      ],
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
        0: pw.FixedColumnWidth(25),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(2.4),
        4: pw.FlexColumnWidth(2.0),
        5: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tableHeader('#'),
            _tableHeader('Клиент'),
            _tableHeader('Город'),
            _tableHeader('Адрес / телефон'),
            _tableHeader('Задание'),
            _tableHeader('Сумма'),
          ],
        ),
        ...sheet.points.asMap().entries.map((entry) {
          final index = entry.key;
          final point = entry.value;

          return pw.TableRow(
            children: [
              _tableCell('${index + 1}'),
              _tableCell(point.clientName),
              _tableCell(point.city),
              _tableCell('${point.address}\n${point.phone}'),
              _buildItemsCell(point.items),
              _tableCell(
                '${point.totalAmount.toStringAsFixed(2)} ₽',
                align: pw.TextAlign.right,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildItemsCell(List<dynamic> items) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: items.map((item) {
          return pw.Text(
            '${item.productName} × ${item.quantity} '
            '(${item.price.toStringAsFixed(2)} ₽)',
            style: const pw.TextStyle(fontSize: 7.5),
          );
        }).toList(),
      ),
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
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
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

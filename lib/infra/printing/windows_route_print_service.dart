import 'dart:typed_data';

import 'package:mountain_fairytale/infra/printing/pdf/route_sheet_pdf_builder.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/services.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:printing/printing.dart';

class WindowsRoutePrintService implements RoutePrintService {
  final RouteSheetPdfBuilder _pdfBuilder;

  WindowsRoutePrintService(this._pdfBuilder);

  @override
  Future<void> printRouteSheet(DeliveryRouteSheet sheet) async {
    final Uint8List pdfBytes = await _pdfBuilder.build(sheet);

    await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
  }
}

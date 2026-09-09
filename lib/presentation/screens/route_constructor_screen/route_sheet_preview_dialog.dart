import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/printing/pdf/route_sheet_pdf_builder.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:printing/printing.dart';

class RouteSheetPreviewDialog extends StatelessWidget {
  final DeliveryRouteSheet sheet;

  const RouteSheetPreviewDialog({super.key, required this.sheet});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 1000,
        height: 850,
        child: PdfPreview(
          build: (format) {
            return RouteSheetPdfBuilder().build(sheet);
          },
          allowPrinting: true,
          allowSharing: false,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: 'route_sheet.pdf',
        ),
      ),
    );
  }
}

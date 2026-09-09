import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/printing/pdf/route_sheet_pdf_builder.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:printing/printing.dart';

class RouteSheetPreviewDialog extends StatelessWidget {
  final DeliveryRouteSheet sheet;

  const RouteSheetPreviewDialog({
    super.key,
    required this.sheet,
  });

  Future<void> _print(BuildContext context) async {
    final pdfBytes = await RouteSheetPdfBuilder().build(sheet);

    if (!context.mounted) {
      return;
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 1000,
        height: 850,
        child: Column(
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Предпросмотр маршрутного листа',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // PDF Preview
            Expanded(
              child: PdfPreview(
                build: (format) {
                  return RouteSheetPdfBuilder().build(sheet);
                },
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                pdfFileName: 'route_sheet.pdf',
              ),
            ),

            const Divider(height: 1),

            // Кнопки
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppSecondaryButton(
                    text: 'Отмена',
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 12),
                  AppPrimaryButton(
                    text: 'Печать',
                    onPressed: () async {
                      await _print(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
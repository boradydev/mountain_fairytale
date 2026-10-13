import 'package:mountain_fairytale/features/delivery_route/services/route_sheet_pdf_builder.dart';
import 'package:mountain_fairytale/shared/widgets/pdf_route_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_meta_panel.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/delivery_document_editor.dart';

class RouteConstructorScreen extends StatelessWidget {
  final String? existingRouteId;
  const RouteConstructorScreen({super.key, this.existingRouteId});
  @override
  Widget build(BuildContext context) {
    final provider = context.read<RouteConstructorProvider>();
    return DeliveryDocumentEditor(
      provider: provider,
      title: 'Маршрутный лист',
      initialize: () async {
        if (existingRouteId == null) {
          provider.resetForm();
          await provider.loadDirectories();
        } else {
          await provider.loadExistingRouteById(existingRouteId!);
        }
      },
      save: provider.saveRoute,
      changeActive: provider.changeDocumentActive,
      metaBuilder: (key) => RouteMetaPanel(formKey: key),
      printDocument: () async {
        final sheet = provider.currentRouteSheet;
        if (sheet == null) return false;
        try {
          final pdf = await RouteSheetPdfBuilder().build(sheet);
          if (!context.mounted) return false;
          await showDialog<void>(
            context: context,
            builder: (_) => PdfRoutePreviewDialog(pdfBytes: pdf),
          );
          return true;
        } catch (_) {
          return false;
        }
      },
    );
  }
}

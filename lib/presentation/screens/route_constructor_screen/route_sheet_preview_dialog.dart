import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/printing/pdf/route_sheet_pdf_builder.dart';
import 'package:mountain_fairytale/infra/repos/delivery_route/models/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';

class RouteSheetPreviewDialog extends StatefulWidget {
  final DeliveryRouteSheet sheet;

  const RouteSheetPreviewDialog({
    super.key,
    required this.sheet,
  });

  @override
  State<RouteSheetPreviewDialog> createState() =>
      _RouteSheetPreviewDialogState();
}

class _RouteSheetPreviewDialogState extends State<RouteSheetPreviewDialog> {
  final PdfViewerController _pdfController = PdfViewerController();

  Uint8List? _pdfBytes;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _buildPdf();
  }

  Future<void> _buildPdf() async {
    try {
      final bytes = await RouteSheetPdfBuilder().build(widget.sheet);

      if (!mounted) {
        return;
      }

      setState(() {
        _pdfBytes = bytes;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _print() async {
    final bytes = _pdfBytes;

    if (bytes == null) {
      return;
    }

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 1200,
        height: 850,
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: _buildPreview(),
            ),
            const Divider(height: 1),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
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
    );
  }

  Widget _buildPreview() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Не удалось подготовить PDF:\n$_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bytes = _pdfBytes;

    if (bytes == null) {
      return const SizedBox.shrink();
    }

    return PdfViewer.data(
      bytes,
      sourceName: 'route_sheet.pdf',
      controller: _pdfController,
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Spacer(),
          AppSecondaryButton(
            text: 'Отмена',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 12),
          AppPrimaryButton(
            text: 'Печать',
            onPressed: _pdfBytes == null ? null : _print,
          ),
        ],
      ),
    );
  }
}
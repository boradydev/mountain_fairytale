import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfRoutePreviewDialog extends StatefulWidget {
  final Uint8List pdfBytes;
  final String title;

  const PdfRoutePreviewDialog({
    super.key,
    required this.pdfBytes,
    this.title = 'Предпросмотр маршрутного листа',
  });

  @override
  State<PdfRoutePreviewDialog> createState() => _PdfRoutePreviewDialogState();
}

class _PdfRoutePreviewDialogState extends State<PdfRoutePreviewDialog> {
  late final PdfViewerController _controller;

  int _currentPage = 1;
  int _pageCount = 0;

  bool _printAllPages = true;

  late final TextEditingController _fromPageController;
  late final TextEditingController _toPageController;

  @override
  void initState() {
    super.initState();

    _controller = PdfViewerController();

    _fromPageController = TextEditingController(text: '1');
    _toPageController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _fromPageController.dispose();
    _toPageController.dispose();
    super.dispose();
  }

  void _onDocumentChanged(PdfDocument? document) {
    if (!mounted || document == null) {
      return;
    }

    final pageCount = document.pages.length;

    setState(() {
      _pageCount = pageCount;
      _currentPage = 1;

      _fromPageController.text = '1';
      _toPageController.text = pageCount.toString();
    });
  }

  void _onPageChanged(int? pageNumber) {
    if (!mounted || pageNumber == null) {
      return;
    }

    setState(() {
      _currentPage = pageNumber;
    });
  }

  Future<void> _goToPreviousPage() async {
    if (_currentPage <= 1) {
      return;
    }

    await _controller.goToPage(
      pageNumber: _currentPage - 1,
      anchor: PdfPageAnchor.top,
    );
  }

  Future<void> _goToNextPage() async {
    if (_currentPage >= _pageCount) {
      return;
    }

    await _controller.goToPage(
      pageNumber: _currentPage + 1,
      anchor: PdfPageAnchor.top,
    );
  }

  Future<void> _goToPage(int pageNumber) async {
    if (_pageCount == 0) {
      return;
    }

    final normalizedPage = pageNumber.clamp(1, _pageCount);

    await _controller.goToPage(
      pageNumber: normalizedPage,
      anchor: PdfPageAnchor.top,
    );
  }

  int? _parsePage(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());

    if (value == null) {
      return null;
    }

    return value;
  }

  bool _validatePageRange() {
    final from = _parsePage(_fromPageController);
    final to = _parsePage(_toPageController);

    if (from == null || to == null) {
      return false;
    }

    if (from < 1 || to < 1) {
      return false;
    }

    if (from > _pageCount || to > _pageCount) {
      return false;
    }

    if (from > to) {
      return false;
    }

    return true;
  }

  void _showPrintSelection() {
    if (_pageCount == 0) {
      return;
    }

    setState(() {
      _printAllPages = true;
      _fromPageController.text = '1';
      _toPageController.text = _pageCount.toString();
    });
  }

  void _selectCurrentPageForPrint() {
    setState(() {
      _printAllPages = false;
      _fromPageController.text = _currentPage.toString();
      _toPageController.text = _currentPage.toString();
    });
  }

  void _selectCustomRangeForPrint() {
    setState(() {
      _printAllPages = false;
    });
  }

  void _print() {
    if (_pageCount == 0) {
      return;
    }

    if (!_printAllPages && !_validatePageRange()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите корректный диапазон страниц'),
        ),
      );

      return;
    }

    final from = _printAllPages ? 1 : _parsePage(_fromPageController)!;

    final to = _printAllPages ? _pageCount : _parsePage(_toPageController)!;

    Navigator.of(context).pop(
      PdfPrintRange(
        fromPage: from,
        toPage: to,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 1200,
        height: 850,
        child: Column(
          children: [
            _buildHeader(colorScheme),
            const Divider(height: 1),

            Expanded(
              child: _buildViewer(),
            ),

            const Divider(height: 1),

            _buildPrintPanel(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
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

  Widget _buildViewer() {
    return Container(
      color: Colors.grey.shade300,
      child: PdfViewer.data(
        widget.pdfBytes,
        sourceName: 'route_sheet.pdf',
        controller: _controller,
        params: PdfViewerParams(
          margin: 16,
          backgroundColor: Colors.grey.shade300,
          pageDropShadow: const BoxShadow(
            blurRadius: 8,
            spreadRadius: 1,
            color: Colors.black26,
          ),
          onDocumentChanged: _onDocumentChanged,
          onPageChanged: _onPageChanged,
        ),
      ),
    );
  }

  Widget _buildPrintPanel(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          _buildPageNavigation(),

          const SizedBox(width: 24),

          const VerticalDivider(),

          const SizedBox(width: 24),

          Expanded(
            child: _buildPrintRangeSelector(),
          ),

          const SizedBox(width: 20),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),

          const SizedBox(width: 8),

          FilledButton.icon(
            onPressed: _print,
            icon: const Icon(Icons.print),
            label: const Text('Печать'),
          ),
        ],
      ),
    );
  }

  Widget _buildPageNavigation() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Предыдущая страница',
          onPressed: _currentPage > 1 ? _goToPreviousPage : null,
          icon: const Icon(Icons.chevron_left),
        ),

        SizedBox(
          width: 70,
          child: Center(
            child: Text(
              _pageCount == 0 ? '—' : '$_currentPage / $_pageCount',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        IconButton(
          tooltip: 'Следующая страница',
          onPressed: _currentPage < _pageCount ? _goToNextPage : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildPrintRangeSelector() {
    return Row(
      children: [
        const Text(
          'Печать:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(width: 16),

        Radio<bool>(
          value: true,
          groupValue: _printAllPages,
          onChanged: (_) {
            _showPrintSelection();
          },
        ),

        const Text('Все страницы'),

        const SizedBox(width: 12),

        Radio<bool>(
          value: false,
          groupValue: _printAllPages,
          onChanged: (_) {
            _selectCustomRangeForPrint();
          },
        ),

        const Text('Диапазон'),

        const SizedBox(width: 8),

        SizedBox(
          width: 65,
          child: TextField(
            controller: _fromPageController,
            enabled: !_printAllPages,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'От',
              isDense: true,
            ),
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('—'),
        ),

        SizedBox(
          width: 65,
          child: TextField(
            controller: _toPageController,
            enabled: !_printAllPages,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'До',
              isDense: true,
            ),
          ),
        ),

        const SizedBox(width: 12),

        TextButton(
          onPressed: _selectCurrentPageForPrint,
          child: const Text('Текущая'),
        ),
      ],
    );
  }
}

class PdfPrintRange {
  final int fromPage;
  final int toPage;

  const PdfPrintRange({
    required this.fromPage,
    required this.toPage,
  });
}

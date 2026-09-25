import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:printing/printing.dart';

enum _PrintMode {
  all,
  range,
  current,
}

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

  _PrintMode _printMode = _PrintMode.all;
  bool _isPrinting = false;

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

      if (_printMode == _PrintMode.current) {
        _fromPageController.text = pageNumber.toString();
        _toPageController.text = pageNumber.toString();
      }
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

  void _selectPrintMode(_PrintMode mode) {
    setState(() {
      _printMode = mode;

      switch (mode) {
        case _PrintMode.all:
          _fromPageController.text = '1';
          _toPageController.text = _pageCount.toString();
          break;

        case _PrintMode.range:
          if (_fromPageController.text.isEmpty) {
            _fromPageController.text = '1';
          }

          if (_toPageController.text.isEmpty) {
            _toPageController.text = _pageCount.toString();
          }
          break;

        case _PrintMode.current:
          _fromPageController.text = _currentPage.toString();
          _toPageController.text = _currentPage.toString();
          break;
      }
    });
  }

  Future<Uint8List> _buildPrintPdf(
    int fromPage,
    int toPage,
  ) async {
    final sourceDocument = await PdfDocument.openData(
      widget.pdfBytes,
      sourceName: 'route_sheet.pdf',
    );

    final printDocument = await PdfDocument.createNew(
      sourceName: 'route_sheet_print.pdf',
    );

    try {
      printDocument.pages = [
        ...sourceDocument.pages.sublist(
          fromPage - 1,
          toPage,
        ),
      ];

      return await printDocument.encodePdf();
    } finally {
      await printDocument.dispose();
      await sourceDocument.dispose();
    }
  }

  Future<void> _print() async {
    if (_pageCount == 0 || _isPrinting) {
      return;
    }

    int from;
    int to;

    switch (_printMode) {
      case _PrintMode.all:
        from = 1;
        to = _pageCount;
        break;

      case _PrintMode.range:
        if (!_validatePageRange()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Укажите корректный диапазон страниц'),
            ),
          );
          return;
        }

        from = _parsePage(_fromPageController)!;
        to = _parsePage(_toPageController)!;
        break;

      case _PrintMode.current:
        from = _currentPage;
        to = _currentPage;
        break;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final pdfBytes = await _buildPrintPdf(from, to);

      if (!mounted) {
        return;
      }

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отправить документ на печать'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
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

          const SizedBox(width: 20),

          const VerticalDivider(),

          const SizedBox(width: 20),

          _buildZoomControls(),

          const SizedBox(width: 24),

          const VerticalDivider(),

          const SizedBox(width: 24),

          Expanded(
            child: _buildPrintRangeSelector(),
          ),

          const SizedBox(width: 20),

          AppSecondaryButton(
            text: 'Отмена',
            onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
          ),

          const SizedBox(width: 8),

          AppPrimaryButton(
            text: _isPrinting ? 'Печать...' : 'Печать',
            onPressed: _isPrinting ? null : _print,
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

        const SizedBox(width: 12),

        Radio<_PrintMode>(
          value: _PrintMode.all,
          groupValue: _printMode,
          onChanged: (value) {
            if (value != null) {
              _selectPrintMode(value);
            }
          },
        ),
        const Text('Все страницы'),

        const SizedBox(width: 8),

        Radio<_PrintMode>(
          value: _PrintMode.range,
          groupValue: _printMode,
          onChanged: (value) {
            if (value != null) {
              _selectPrintMode(value);
            }
          },
        ),
        const Text('Диапазон'),

        const SizedBox(width: 8),

        SizedBox(
          width: 58,
          child: TextField(
            controller: _fromPageController,
            enabled: _printMode == _PrintMode.range,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'От',
              isDense: true,
            ),
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('—'),
        ),

        SizedBox(
          width: 58,
          child: TextField(
            controller: _toPageController,
            enabled: _printMode == _PrintMode.range,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'До',
              isDense: true,
            ),
          ),
        ),

        const SizedBox(width: 8),

        Radio<_PrintMode>(
          value: _PrintMode.current,
          groupValue: _printMode,
          onChanged: (value) {
            if (value != null) {
              _selectPrintMode(value);
            }
          },
        ),
        const Text('Текущая'),
      ],
    );
  }

  Future<void> _zoomOut() async {
    await _controller.zoomDown();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _zoomIn() async {
    await _controller.zoomUp();
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildZoomControls() {
    final zoom = (_controller.currentZoom * 100).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Уменьшить',
          onPressed: _zoomOut,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 56,
          child: Center(
            child: Text(
              '$zoom%',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Увеличить',
          onPressed: _zoomIn,
          icon: const Icon(Icons.add),
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

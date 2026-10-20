import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_optimization_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_selection_panel.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_points_list.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/theme_toggle_button.dart';

/// Shared document lifecycle for delivery and pickup constructors.
class DeliveryDocumentEditor extends StatefulWidget {
  final OrderPointsProvider provider;
  final String title;
  final Future<void> Function() initialize;
  final Future<bool> Function() save;
  final Future<bool> Function() changeActive;
  final Widget Function(GlobalKey<FormState>) metaBuilder;
  final Future<bool> Function()? printDocument;
  final VoidCallback? onDocumentChanged;
  const DeliveryDocumentEditor({
    super.key,
    required this.provider,
    required this.title,
    required this.initialize,
    required this.save,
    required this.changeActive,
    required this.metaBuilder,
    this.printDocument,
    this.onDocumentChanged,
  });
  @override
  State<DeliveryDocumentEditor> createState() => _DeliveryDocumentEditorState();
}

class _DeliveryDocumentEditorState extends State<DeliveryDocumentEditor> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _canPop = false;
  bool _lastEditing = false;
  bool _leaving = false;
  ({bool creating, bool editing})? _savePresentation;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.initialize();
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<bool> _close({bool afterSave = false}) async {
    if (_leaving ||
        widget.provider.documentBusy ||
        (_savePresentation != null && !afterSave)) {
      return false;
    }
    setState(() => _leaving = true);
    final success = await widget.provider.closeDocument();
    if (!mounted) return false;
    if (!success) {
      setState(() => _leaving = false);
      return false;
    }
    setState(() => _canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return false;
    Navigator.of(context).pop(widget.provider.documentChanged);
    return true;
  }

  Future<void> _save() async {
    if (_savePresentation != null ||
        _leaving ||
        !widget.provider.canSave ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(
      () => _savePresentation = (
        creating: widget.provider.documentId == null,
        editing: widget.provider.isEditing,
      ),
    );
    var closed = false;
    try {
      if (!await widget.save() || !mounted) return;
      widget.onDocumentChanged?.call();
      closed = await _close(afterSave: true);
    } finally {
      // Keep the presentation through the reverse route animation on success.
      // On failure, show the provider's real mode and allow recovery.
      if (mounted && !closed) setState(() => _savePresentation = null);
    }
  }

  Future<void> _changeActive() async {
    final active = widget.provider.documentActive;
    final confirmed = await ConfirmDialog.show(
      context,
      title: active ? 'Отменить документ?' : 'Восстановить документ?',
      content: active
          ? 'Документ будет отменён. Несохранённые изменения формы не сохранятся.'
          : 'Документ снова станет активным со всеми сохранёнными данными.',
      confirmText: active ? 'Отменить документ' : 'Восстановить',
      destructive: active,
    );
    if (!mounted || !confirmed) return;
    if (await widget.changeActive()) widget.onDocumentChanged?.call();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) {
      final p = widget.provider;
      final creating = _savePresentation?.creating ?? (p.documentId == null);
      final editing = _savePresentation?.editing ?? p.isEditing;
      final busy = p.documentBusy || _savePresentation != null || _leaving;
      final mode = creating
          ? 'создание'
          : editing
          ? 'редактирование'
          : 'просмотр';
      if (editing != _lastEditing) _formKey = GlobalKey<FormState>();
      _lastEditing = editing;
      return PopScope(
        canPop: _canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _close();
        },
        child: AbsorbPointer(
          absorbing: _savePresentation != null || _leaving,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: busy ? null : _close,
              ),
              title: Text('${widget.title} ($mode)'),
              actions: [
                if (p is RouteConstructorProvider)
                  AppIconButton(
                    icon: Icons.format_list_numbered,
                    tooltip: 'Порядок доставок',
                    onPressed: _loading || busy
                        ? null
                        : () =>
                              showRouteOptimizationDialog(context, provider: p),
                  ),
                if (widget.printDocument != null)
                  AppIconButton(
                    icon: Icons.print,
                    tooltip: 'Печать документа',
                    onPressed: _loading || busy
                        ? null
                        : () async {
                            if (!await widget.printDocument!() &&
                                context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Не удалось напечатать документ.',
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('Итого: ${p.grandTotal.toStringAsFixed(2)} ₽'),
                  ),
                ),
                const ThemeToggleButton(),
              ],
            ),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (!p.documentActive)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Документ отменён. Для редактирования восстановите его.',
                          ),
                        ),
                      if (p.documentError != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            p.documentError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 4,
                        child: busy
                            ? const LinearProgressIndicator(minHeight: 4)
                            : null,
                      ),
                      Expanded(
                        child: Form(
                          key: _formKey,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 360,
                                child: ExcludeFocus(
                                  excluding: !p.canEdit,
                                  child: AbsorbPointer(
                                    absorbing: !p.canEdit,
                                    child: Column(
                                      children: [
                                        widget.metaBuilder(_formKey),
                                        const Divider(height: 1),
                                        Expanded(
                                          child: ClientSelectionPanel(
                                            provider: p,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: RoutePointsList(provider: p),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 160,
                    child: AppSecondaryButton(
                      maxLines: 1,
                      text: !creating && editing ? 'Отмена' : 'Закрыть',
                      onPressed: _loading || busy
                          ? null
                          : !creating && editing
                          ? p.cancelEditing
                          : _close,
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: creating || editing
                        ? AppPrimaryButton(
                            maxLines: 1,
                            text: 'Сохранить',
                            onPressed: !_loading && !busy && p.canSave
                                ? _save
                                : null,
                          )
                        : p.documentActive
                        ? AppPrimaryButton(
                            maxLines: 1,
                            text: 'Начать редактирование',
                            onPressed: _loading || busy ? null : p.beginEditing,
                          )
                        : null,
                  ),
                  // Keep the same horizontal slots in creation, view and edit.
                  SizedBox(
                    width: 220,
                    child: !creating && !editing
                        ? AppSecondaryButton(
                            maxLines: 1,
                            text: p.documentActive
                                ? 'Отменить документ'
                                : 'Восстановить',
                            onPressed: _loading || busy ? null : _changeActive,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

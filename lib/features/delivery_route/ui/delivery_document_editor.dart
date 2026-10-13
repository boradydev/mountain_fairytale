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
  const DeliveryDocumentEditor({
    super.key,
    required this.provider,
    required this.title,
    required this.initialize,
    required this.save,
    required this.changeActive,
    required this.metaBuilder,
    this.printDocument,
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.initialize();
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _close() async {
    if (_leaving || widget.provider.documentBusy) return;
    _leaving = true;
    final success = await widget.provider.closeDocument();
    _leaving = false;
    if (!mounted || !success) return;
    setState(() => _canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop(widget.provider.documentChanged);
  }

  Future<void> _save() async {
    if (!widget.provider.canSave ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (await widget.save()) await _close();
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
    await widget.changeActive();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) {
      final p = widget.provider;
      if (p.isEditing && !_lastEditing) _formKey = GlobalKey<FormState>();
      _lastEditing = p.isEditing;
      return PopScope(
        canPop: _canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _close();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: p.documentBusy ? null : _close,
            ),
            title: Text(widget.title),
            actions: [
              if (widget.printDocument != null)
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Печать документа',
                  onPressed: _loading || p.documentBusy
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
                    if (p.documentId != null &&
                        !p.isEditing &&
                        p.documentActive)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Просмотр. Начните редактирование, чтобы изменить документ.',
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
                    if (p.documentBusy) const LinearProgressIndicator(),
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
                            Expanded(child: RoutePointsList(provider: p)),
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
                AppSecondaryButton(
                  text: 'Закрыть',
                  onPressed: _loading || p.documentBusy ? null : _close,
                ),
                if (p.documentId != null)
                  AppSecondaryButton(
                    text: p.documentActive
                        ? 'Отменить документ'
                        : 'Восстановить',
                    onPressed: _loading || p.documentBusy
                        ? null
                        : _changeActive,
                  ),
                if (p.documentId != null && p.documentActive && !p.isEditing)
                  AppPrimaryButton(
                    text: 'Начать редактирование',
                    onPressed: _loading || p.documentBusy
                        ? null
                        : p.beginEditing,
                  ),
                if (p.documentId == null || p.isEditing)
                  AppPrimaryButton(
                    text: 'Сохранить',
                    onPressed: !_loading && p.canSave ? _save : null,
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

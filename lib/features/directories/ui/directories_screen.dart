import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/directories/ui/directories_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/products/data/product_model.dart';
import 'package:mountain_fairytale/features/products/ui/product_dialog.dart';
import 'package:mountain_fairytale/features/drivers/data/driver_model.dart';
import 'package:mountain_fairytale/features/drivers/ui/driver_dialog.dart';
import 'package:mountain_fairytale/features/cars/data/cars_model.dart';
import 'package:mountain_fairytale/features/cars/data/cars_number.dart';
import 'package:mountain_fairytale/features/cars/ui/car_dialog.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_dialog.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/features/sales_representatives/ui/sales_rep_dialog.dart';
import 'package:mountain_fairytale/features/commissions/ui/commission_widgets.dart';
import 'package:mountain_fairytale/shared/widgets/add_action_card.dart';
import 'package:mountain_fairytale/shared/widgets/base_card_widget.dart';
import 'package:mountain_fairytale/shared/widgets/labeled_checkbox_toggle.dart';
import 'package:mountain_fairytale/shared/widgets/list_section_header.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/app_notify.dart';

class DirectoriesScreen extends StatefulWidget {
  const DirectoriesScreen({super.key});
  @override
  State<DirectoriesScreen> createState() => _DirectoriesScreenState();
}

class _DirectoriesScreenState extends State<DirectoriesScreen> {
  bool _visible = false;
  bool _opening = false;
  bool _reading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) context.read<DirectoriesProvider>().refresh();
      });
    }
    _visible = visible;
  }

  Future<void> _openEditor([Object? record]) async {
    if (_opening) return;
    final provider = context.read<DirectoriesProvider>();
    final section = provider.section;
    setState(() => _opening = true);
    try {
      do {
        setState(() => _reading = record != null);
        final current = record == null
            ? null
            : await provider.readCurrent(record);
        if (!mounted) return;
        setState(() => _reading = false);
        final editor = provider.createEditor();
        Object? openAfter;
        try {
          await showDialog<Object?>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              void open(Object existing) {
                openAfter = existing;
                Navigator.pop(dialogContext);
              }

              final form = switch (section) {
                DirectorySection.products => ProductDialog(
                  provider: editor,
                  product: current as Product?,
                  directoryMode: true,
                  onOpenProduct: open,
                ),
                DirectorySection.drivers => DriverDialog(
                  driver: current as Driver?,
                  directoryMode: true,
                  onOpenDriver: open,
                ),
                DirectorySection.cars => CarDialog(
                  car: current as Car?,
                  directoryMode: true,
                  onOpenCar: open,
                ),
                DirectorySection.paymentMethods => PaymentMethodDialog(
                  provider: editor,
                  paymentMethod: current as PaymentMethod?,
                  directoryMode: true,
                  onOpenPaymentMethod: open,
                ),
                DirectorySection.representatives => SalesRepDialog(
                  apiRepository: provider.representatives,
                  apiSalesRep: current as ApiSalesRepresentative?,
                  directoryMode: true,
                  onOpenSalesRep: open,
                ),
              };
              return ChangeNotifierProvider<RouteConstructorProvider>.value(
                value: editor,
                child: form,
              );
            },
          );
        } finally {
          editor.dispose();
        }
        record = openAfter;
      } while (mounted && record != null);
    } catch (_) {
      if (mounted) {
        AppNotify.show(
          'Не удалось открыть запись. Повторите попытку.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          _reading = false;
        });
        await provider.refresh(section);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DirectoriesProvider>();
    final state = provider.current;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListSectionHeader(
          title: 'Справочники',
          description: 'Добавление, редактирование и управление активностью.',
          controls: Row(
            children: [
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<DirectorySection>(
                    showSelectedIcon: false,
                    segments: [
                      for (final section in DirectorySection.values)
                        ButtonSegment(
                          value: section,
                          label: Text(section.label),
                        ),
                    ],
                    selected: {provider.section},
                    onSelectionChanged: (selection) =>
                        provider.selectSection(selection.single),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: colors.primary,
                      selectedForegroundColor: colors.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              LabeledCheckboxToggle(
                label: 'Деактивированные',
                value: state.includeDeactivated,
                onChanged: provider.setIncludeDeactivated,
                tooltip:
                    'Показывать деактивированные записи вместе с активными',
              ),
            ],
          ),
        ),
        SizedBox(
          height: 4,
          child: state.loading || _reading
              ? const LinearProgressIndicator(minHeight: 4)
              : null,
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(state.error!),
                AppSecondaryButton(
                  text: 'Повторить',
                  onPressed: () => provider.refresh(),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            key: PageStorageKey(provider.section),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.items.length + 1,
            itemBuilder: (context, index) => index == 0
                ? AddActionButton(
                    label: provider.section.addLabel,
                    icon: Icons.add_circle_outline,
                    onTap: () => _openEditor(),
                  )
                : _DirectoryCard(
                    record: state.items[index - 1],
                    onTap: () => _openEditor(state.items[index - 1]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({required this.record, required this.onTap});
  final Object record;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final (name, active, description) = switch (record) {
      Product p => (
        p.name,
        p.isActive,
        'Цена: ${p.basePrice} ₽',
      ),
      Driver d => (d.name, d.isActive, ''),
      Car c => (
        c.model,
        c.isActive,
        '${formatCarNumber(c.number)} · Текущий пробег: ${c.currentMileage} км',
      ),
      PaymentMethod p => (p.name, p.isActive, ''),
      ApiSalesRepresentative r => (
        r.name,
        r.isActive,
        '${r.phone} · Вознаграждение: ${r.commissionPercent}%',
      ),
      _ => throw ArgumentError('Unsupported directory entry'),
    };
    return AppBaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommissionPersonHeader(name: name, isActive: active),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description),
          ],
        ],
      ),
    );
  }
}

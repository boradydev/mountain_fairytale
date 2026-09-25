import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/printing/pdf/route_sheet_pdf_builder.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/common/clients_selection_panel.dart';
import 'package:mountain_fairytale/presentation/screens/orders/route_constructor/route_meta_panel.dart';
import 'package:mountain_fairytale/presentation/screens/orders/route_constructor/route_points_list.dart';
import 'package:mountain_fairytale/presentation/screens/orders/route_constructor/route_sheet_preview_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/app_notify.dart';
import 'package:mountain_fairytale/presentation/widgets/pdf_route_preview_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class RouteConstructorScreen extends StatefulWidget {
  final int? existingRouteId;

  const RouteConstructorScreen({super.key, this.existingRouteId});

  @override
  State<RouteConstructorScreen> createState() => _RouteConstructorScreenState();
}

class _RouteConstructorScreenState extends State<RouteConstructorScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Проверяем mounted самого State перед использованием context
      if (!mounted) return;

      final routeProvider = context.read<RouteConstructorProvider>();

      if (widget.existingRouteId != null) {
        await routeProvider.loadExistingRouteById(widget.existingRouteId!);

        if (routeProvider.isOldDocument) {
          AppNotify.show(
            'Маршрут недельной давности и более',
            isWarning: true,
          );
        }
      } else {
        routeProvider.resetForm();
        routeProvider.loadDirectories();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteConstructorProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingRouteId != null
              ? 'Просмотр маршрутного листа'
              : 'Конструктор маршрутного листа',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Печать маршрутного листа',
            onPressed: () {
              if (provider.selectedDriver == null) {
                AppNotify.show(
                  'Укажите водителя перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }
              if (provider.selectedCar == null) {
                AppNotify.show(
                  'Укажите автомобиль перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }
              if (provider.points.isEmpty) {
                AppNotify.show(
                  'Добавьте хотя бы один маршрут перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }

              final hasProducts = provider.points.any(
                (point) => point.items.isNotEmpty,
              );
              if (!hasProducts) {
                AppNotify.show(
                  'Добавьте продукцию хотя бы в один маршрут перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }

              final sheet = provider.currentRouteSheet;
              if (sheet == null) {
                AppNotify.show(
                  'Не удалось подготовить маршрутный лист к печати',
                  isError: true,
                );
                return;
              }

              showDialog(
                context: context,
                builder: (_) => RouteSheetPreviewDialog(sheet: sheet),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Печать маршрутного листа',
            onPressed: () async {
              if (provider.selectedDriver == null) {
                AppNotify.show(
                  'Укажите водителя перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }

              if (provider.selectedCar == null) {
                AppNotify.show(
                  'Укажите автомобиль перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }

              if (provider.points.isEmpty) {
                AppNotify.show(
                  'Добавьте хотя бы один маршрут перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }

              final hasProducts = provider.points.any(
                    (point) => point.items.isNotEmpty,
              );

              if (!hasProducts) {
                AppNotify.show(
                  'Добавьте продукцию хотя бы в один маршрут перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }

              final sheet = provider.currentRouteSheet;

              if (sheet == null) {
                AppNotify.show(
                  'Не удалось подготовить маршрутный лист к печати',
                  isError: true,
                );
                return;
              }

              try {
                final pdfBytes = await RouteSheetPdfBuilder().build(sheet);

                if (!context.mounted) {
                  return;
                }

                await showDialog(
                  context: context,
                  builder: (_) => PdfRoutePreviewDialog(
                    pdfBytes: pdfBytes,
                    title: 'Предпросмотр маршрутного листа',
                  ),
                );
              } catch (e) {
                if (!context.mounted) {
                  return;
                }

                AppNotify.show(
                  'Не удалось сформировать маршрутный лист',
                  isError: true,
                );
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                'Итого по маршруту: ${provider.grandTotal.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: provider.isLoadingDirectories
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ЛЕВАЯ ЧАСТЬ: Фиксированная колонка панелей
                  SizedBox(
                    width: 360,
                    child: Column(
                      children: [
                        RouteMetaPanel(formKey: _formKey),
                        const Divider(height: 1),
                        Expanded(
                          child: ClientSelectionPanel(
                            provider: context.watch<RouteConstructorProvider>(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),

                  // ПРАВАЯ ЧАСТЬ: Полностью отведена под список точек маршрута
                  Expanded(
                    child: RoutePointsList(
                      provider: context.watch<RouteConstructorProvider>(),
                    ),
                  ),
                ],
              ),
            ),
      // Кнопки управления теперь железно зафиксированы внизу экрана
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Padding(
          // идеально центрирует кнопки относительно правого списка точек
          padding: const EdgeInsets.only(left: 361.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              // Кнопка Отмена
              AppSecondaryButton(
                text: 'Отмена',
                onPressed: () {
                  Navigator.pop(context, false);
                },
              ),
              const SizedBox(width: 16),
              // Кнопка Сохранить
              AppPrimaryButton(
                text: 'Сохранить маршрут',
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final success = await provider.saveRoute();
                    if (!context.mounted) return;

                    if (success) {
                      AppNotify.show('Маршрутный лист сохранен');
                      Navigator.pop(context, true);
                    } else {
                      AppNotify.show(
                        'Ошибка при сохранении маршрута',
                        isError: true,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

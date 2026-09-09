import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/app_notify.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/flight_meta_panel.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/route_points_list.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/route_sheet_preview_dialog.dart';
import 'package:provider/provider.dart';

class RouteConstructorScreen extends StatefulWidget {
  final DateTime? existingDate; // Передаем дату, если открываем на просмотр/редактирование

  const RouteConstructorScreen({super.key, this.existingDate});

  @override
  State<RouteConstructorScreen> createState() => _RouteConstructorScreenState();
}

class _RouteConstructorScreenState extends State<RouteConstructorScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeProvider = context.read<RouteConstructorProvider>();

      if (widget.existingDate != null) {
        // Режим просмотра/редактирования существующего дня
        routeProvider.loadExistingRoute(widget.existingDate!);
      } else {
        // Режим создания нового маршрута на сегодня
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
        title: Text(widget.existingDate != null
            ? 'Просмотр маршрутного листа'
            : 'Конструктор маршрутного листа'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Печать маршрутного листа',
            onPressed: () {
              if (provider.selectedDriver == null) {
                AppNotify.show(
                  context,
                  'Укажите водителя перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }

              if (provider.selectedCar == null) {
                AppNotify.show(
                  context,
                  'Укажите автомобиль перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }

              if (provider.points.isEmpty) {
                AppNotify.show(
                  context,
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
                  context,
                  'Добавьте продукцию хотя бы в один маршрут перед печатью маршрутного листа',
                  isError: true,
                );
                return;
              }

              final sheet = provider.currentRouteSheet;

              if (sheet == null) {
                AppNotify.show(
                  context,
                  'Не удалось подготовить маршрутный лист к печати',
                  isError: true,
                );
                return;
              }

              showDialog(
                context: context,
                builder: (_) => RouteSheetPreviewDialog(
                  sheet: sheet,
                ),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                'Итого по маршруту: '
                    '${provider.grandTotal.toStringAsFixed(2)} ₽',
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
          children: [
            FlightMetaPanel(formKey: _formKey),
            const Expanded(child: RoutePointsList()),
          ],
        ),
      ),
    );
  }
}

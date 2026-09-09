import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/app_notify.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/flight_meta_panel.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/route_points_list.dart';
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
            onPressed: provider.points.isEmpty ||
                provider.selectedDriver == null ||
                provider.selectedCar == null
                ? null
                : () async {
              final success = await provider.printRoute();

              if (!context.mounted) return;

              if (!success) {
                AppNotify.show(
                  context,
                  'Не удалось подготовить маршрутный лист к печати',
                  isError: true,
                );
              }
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

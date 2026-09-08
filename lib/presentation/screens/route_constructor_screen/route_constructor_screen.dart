import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/route_constructor_provider.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/flight_meta_panel.dart';
import 'package:mountain_fairytale/presentation/screens/route_constructor_screen/route_points_list.dart';
import 'package:provider/provider.dart';

class RouteConstructorScreen extends StatefulWidget {
  const RouteConstructorScreen({super.key});

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
      routeProvider.resetForm(); // Очищаем старые точки, предотвращая дубликаты Key
      routeProvider.loadDirectories();
    });
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteConstructorProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Конструктор маршрутного листа'),
        actions: [
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
                children: [
                  // Левая панель: Ввод данных рейса + Подгрузка клиентов
                  FlightMetaPanel(formKey: _formKey),

                  // Правая интерактивная панель: Сортируемый список точек
                  const Expanded(child: RoutePointsList()),
                ],
              ),
            ),
    );
  }
}

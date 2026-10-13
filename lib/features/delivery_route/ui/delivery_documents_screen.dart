import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/delivery_route/delivery_route_abcs.dart';
import 'package:mountain_fairytale/features/pickup/pickup_abcs.dart';
import 'package:mountain_fairytale/features/delivery_route/data/delivery_route_sheet_model.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_screen.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_screen.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class DeliveryDocumentsScreen extends StatefulWidget {
  const DeliveryDocumentsScreen({super.key});
  @override
  State<DeliveryDocumentsScreen> createState() =>
      _DeliveryDocumentsScreenState();
}

class _DeliveryDocumentsScreenState extends State<DeliveryDocumentsScreen> {
  List<RouteDocument> _documents = [];
  bool _includeCancelled = false;
  bool _loading = true;
  String? _error;
  int _loadVersion = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    final routes = context.read<DeliveryRouteRepository>();
    final pickups = context.read<PickupRepository>();
    try {
      final result = await Future.wait([
        routes.getRouteSheets(includeCancelled: _includeCancelled),
        pickups.getPickupSheets(includeCancelled: _includeCancelled),
      ]);
      if (!mounted || version != _loadVersion) return;
      final documents = <RouteDocument>[...result[0], ...result[1]];
      documents.sort((a, b) {
        final order = (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date);
        return order != 0 ? order : (b.id ?? '').compareTo(a.id ?? '');
      });
      setState(() => _documents = documents);
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(
          () => _error = 'Не удалось загрузить документы. Повторите запрос.',
        );
      }
    } finally {
      if (mounted && version == _loadVersion) setState(() => _loading = false);
    }
  }

  Future<void> _open({RouteDocument? document, bool delivery = true}) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            document is DeliveryRouteSheet || (document == null && delivery)
            ? RouteConstructorScreen(existingRouteId: document?.id)
            : PickupConstructorScreen(existingPickupId: document?.id),
      ),
    );
    if (mounted && updated == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Документы доставки и самовывоза')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppPrimaryButton(
                text: 'Создать доставку',
                onPressed: () => _open(),
              ),
              AppPrimaryButton(
                text: 'Создать самовывоз',
                onPressed: () => _open(delivery: false),
              ),
              AppSecondaryButton(
                text: 'Обновить',
                onPressed: _loading ? null : _load,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _includeCancelled,
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() => _includeCancelled = value);
                            _load();
                          },
                  ),
                  const Text('Показывать отменённые'),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _documents.isEmpty
              ? const Center(child: Text('Документов пока нет.'))
              : ListView.builder(
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final document = _documents[index];
                    return ListTile(
                      leading: Icon(
                        document is DeliveryRouteSheet
                            ? Icons.local_shipping_outlined
                            : Icons.inventory_2_outlined,
                      ),
                      title: Text(
                        '${document.title}${document.isActive ? '' : ' — Отменён'}',
                      ),
                      subtitle: Text(
                        'Плановая дата: ${document.date.toIso8601String().substring(0, 10)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(document: document),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

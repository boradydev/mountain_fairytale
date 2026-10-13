import 'package:mountain_fairytale/features/delivery_route/ui/delivery_documents_screen.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/client_list.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_day_list.dart';
import 'package:provider/provider.dart';

class DeliveryDaysScreen extends StatefulWidget {
  const DeliveryDaysScreen({super.key});

  @override
  State<DeliveryDaysScreen> createState() => _DeliveryDaysScreenState();
}

class _DeliveryDaysScreenState extends State<DeliveryDaysScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Первоначальная загрузка данных
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DeliveryDaysProvider>().fetchDeliveryDays();
      context.read<ClientsProvider>().fetchClients();
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<DeliveryDaysProvider>().fetchDeliveryDays();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select((DeliveryDaysProvider p) => p.status);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppSecondaryButton(
              text: 'Документы доставки и самовывоза',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeliveryDocumentsScreen(),
                  ),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: switch (status) {
            DeliveryStatus.initial || DeliveryStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            DeliveryStatus.failure => _ErrorView(),
            DeliveryStatus.success => _Dashboard(
              scrollController: _scrollController,
            ),
          },
        ),
      ],
    );
  }
}

class _Dashboard extends StatelessWidget {
  final ScrollController scrollController;

  const _Dashboard({
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 500,
          child: DeliveryDaysListView(
            scrollController: scrollController,
          ),
        ),
        Expanded(
          flex: 3,
          child: ClientsAttentionListView(),
        ),
      ],
    );
  }
}

/// Изолированный виджет ошибки
class _ErrorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final errorMessage = context.select(
      (DeliveryDaysProvider p) => p.errorMessage,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  context.read<DeliveryDaysProvider>().fetchDeliveryDays(),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/client_list.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DeliveryDaysProvider>().fetchDeliveryDays();
      context.read<ClientsProvider>().fetchClients();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<DeliveryDaysProvider>().fetchDeliveryDays();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 500,
        child: DeliveryDaysListView(scrollController: _scrollController),
      ),
      const Expanded(flex: 3, child: ClientsAttentionListView()),
    ],
  );
}

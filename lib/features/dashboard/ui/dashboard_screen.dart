import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/clients/ui/client_list.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_day_list.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/shared/widgets/list_section_header.dart';

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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final compact = constraints.maxWidth < 960 * scale;
      final headerHeight = AppListSectionHeader.preferredHeight(context).clamp(
        0.0,
        constraints.maxHeight * (compact ? 0.2 : 0.6),
      );
      if (compact) {
        return Column(
          children: [
            Expanded(
              child: DeliveryDaysListView(
                scrollController: _scrollController,
                headerHeight: headerHeight,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 2,
              child: ClientsAttentionListView(
                headerHeight: headerHeight,
              ),
            ),
          ],
        );
      }
      return Row(
        children: [
          SizedBox(
            width: (constraints.maxWidth * 0.38).clamp(360.0, 500.0),
            child: DeliveryDaysListView(
              scrollController: _scrollController,
              headerHeight: headerHeight,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: ClientsAttentionListView(headerHeight: headerHeight),
          ),
        ],
      );
    },
  );
}

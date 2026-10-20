import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_optimization_panel.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

Future<void> showRouteOptimizationDialog(
  BuildContext context, {
  required RouteConstructorProvider provider,
}) => showDialog<void>(
  context: context,
  builder: (_) => RouteOptimizationDialog(provider: provider),
);

class RouteOptimizationDialog extends StatefulWidget {
  final RouteConstructorProvider provider;
  const RouteOptimizationDialog({super.key, required this.provider});

  @override
  State<RouteOptimizationDialog> createState() =>
      _RouteOptimizationDialogState();
}

class _RouteOptimizationDialogState extends State<RouteOptimizationDialog> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) => AlertDialog(
      title: const Text('Порядок доставок'),
      content: SizedBox(
        width: 520,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Scrollbar(
            controller: _scrollController,
            thickness: 6,
            radius: const Radius.circular(3),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(right: 16),
              child: RouteOptimizationPanel(provider: widget.provider),
            ),
          ),
        ),
      ),
      actions: [
        AppSecondaryButton(
          text: 'Закрыть',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/audit_log_provider.dart';
import 'package:mountain_fairytale/presentation/screens/audit_log/audit_event_row.dart';
import 'package:provider/provider.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuditLogProvider>().fetchEvents();
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<AuditLogProvider>().fetchEvents();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (AuditLogProvider p) => p.status,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал событий'),
      ),
      body: Column(
        children: [
          _SearchField(
            controller: _searchController,
            onChanged: (value) {
              context.read<AuditLogProvider>().searchEvents(value);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (status) {
              AuditLogStatus.initial || AuditLogStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),

              AuditLogStatus.failure => _ErrorView(),

              AuditLogStatus.success => _AuditEventList(
                scrollController: _scrollController,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Поиск по журналу...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Очистить',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _AuditEventList extends StatelessWidget {
  final ScrollController scrollController;

  const _AuditEventList({
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final events = context.select(
      (AuditLogProvider p) => p.events,
    );

    final hasMore = context.select(
      (AuditLogProvider p) => p.hasMore,
    );

    final isLoadingMore = context.select(
      (AuditLogProvider p) => p.isLoadingMore,
    );

    if (events.isEmpty) {
      return const Center(
        child: Text('События не найдены'),
      );
    }

    final showLoader = hasMore && isLoadingMore;

    return ListView.separated(
      controller: scrollController,
      itemCount: events.length + (showLoader ? 1 : 0),
      separatorBuilder: (_, index) {
        if (index >= events.length - 1) {
          return const SizedBox.shrink();
        }

        return const Divider(
          height: 1,
          indent: 78,
        );
      },
      itemBuilder: (context, index) {
        if (index == events.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        return AuditEventRow(
          event: events[index],
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<AuditLogProvider>();
    final message = context.select(
      (AuditLogProvider p) => p.errorMessage,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: provider.fetchEvents,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/network/http_transport.dart';
import 'package:mountain_fairytale/features/dashboard/data/dashboard_updates_repo.dart';
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

class _DeliveryDaysScreenState extends State<DeliveryDaysScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  DashboardUpdatesRepository? _updatesRepository;
  DashboardUpdates? _position;
  HttpRequestCancellation? _request;
  Timer? _retryTimer;
  Completer<void>? _retryDone;
  bool _visible = false;
  bool _appActive = true;
  bool _running = false;
  bool _resync = true;
  bool _initialLoadStarted = false;
  bool get _canWatch => mounted && _visible && _appActive;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _appActive = state == null || state == AppLifecycleState.resumed;
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatesRepository = context.read<DashboardUpdatesRepository?>();
    final visible = TickerMode.valuesOf(context).enabled;
    if (_visible == visible) return;
    _visible = visible;
    _watchingChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    _watchingChanged();
  }

  void _wakeRetry() {
    _retryTimer?.cancel();
    final done = _retryDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  void _watchingChanged() {
    _request?.cancel();
    _wakeRetry();
    if (!_canWatch) return;
    _resync = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canWatch) return;
      if (_updatesRepository == null) {
        if (!_initialLoadStarted) {
          _initialLoadStarted = true;
          context.read<DeliveryDaysProvider>().fetchDeliveryDays();
          context.read<ClientsProvider>().fetchClients();
        }
      } else if (!_running) {
        unawaited(_watchUpdates());
      }
    });
  }

  Future<void> _watchUpdates() async {
    if (_running) return;
    _running = true;
    final clients = context.read<ClientsProvider>();
    final days = context.read<DeliveryDaysProvider>();
    var retrySeconds = 1;
    try {
      while (_canWatch) {
        if (_resync) {
          _position = null;
          _resync = false;
        }
        final cancellation = HttpRequestCancellation();
        _request = cancellation;
        try {
          final update = await _updatesRepository!.wait(
            after: _position,
            cancellation: cancellation,
          );
          if (!_canWatch || cancellation.isCancelled) continue;
          final results = await Future.wait([
            if (update.reloadRequired || update.clientsChanged)
              clients.refreshDashboardClients(),
            if (update.reloadRequired || update.deliveryDaysChanged)
              days.refreshDashboardDays(),
          ]);
          if (!_canWatch || cancellation.isCancelled) continue;
          if (results.any((success) => !success)) {
            throw StateError('Dashboard refresh incomplete');
          }
          // Позицию подтверждаем только после успешного обновления списков.
          _position = update;
          retrySeconds = 1;
        } catch (_) {
          if (!_canWatch || cancellation.isCancelled) continue;
          final done = Completer<void>();
          _retryDone = done;
          _retryTimer = Timer(
            Duration(seconds: retrySeconds),
            () => done.complete(),
          );
          await done.future;
          _retryDone = null;
          retrySeconds = (retrySeconds * 2).clamp(1, 15);
        }
      }
    } finally {
      _running = false;
      _request = null;
      if (_canWatch && _resync) unawaited(_watchUpdates());
    }
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
    _visible = false;
    _request?.cancel();
    _wakeRetry();
    WidgetsBinding.instance.removeObserver(this);
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

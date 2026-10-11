import 'package:flutter/material.dart';
import 'package:mountain_fairytale/l10n/app_localizations.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/presentation/screens/login/change_password_dialog.dart';
import 'package:mountain_fairytale/features/delivery_days/ui/delivery_days_provider.dart';
import 'package:mountain_fairytale/features/audit_log/ui/audit_log_screen.dart';
import 'package:mountain_fairytale/presentation/screens/delivery_days/client_list.dart';
import 'package:mountain_fairytale/presentation/screens/delivery_days/delivery_day_list.dart';
import 'package:mountain_fairytale/presentation/screens/sales_analytics/sales_analytics_screen.dart';
import 'package:mountain_fairytale/presentation/widgets/locate_toggle_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/theme_toggle_button.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final status = context.select((DeliveryDaysProvider p) => p.status);
    final auth = context.watch<AuthProvider>();

    // Слушаем состояние фильтра, чтобы менять цвет иконки кнопки
    final showOnlySleeping = context.select(
      (ClientsProvider p) => p.showOnlySleeping,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          PopupMenuButton<String>(
            tooltip: auth.currentUser?.username ?? 'Учётная запись',
            enabled: !auth.isLoading,
            onSelected: (value) async {
              if (value == 'logout') {
                await auth.logout();
              } else if (value == 'password') {
                final changed = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const ChangePasswordDialog(),
                );
                if (!context.mounted || changed != true) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароль изменён.')),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'password', child: Text('Изменить пароль')),
              PopupMenuItem(value: 'logout', child: Text('Выйти')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.account_circle_outlined),
                  const SizedBox(width: 8),
                  Text(auth.currentUser?.username ?? ''),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Журнал событий',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AuditLogScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Вознаграждение торговых представителей',
            icon: const Icon(Icons.payments_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SalesRepresentativeCommissionScreen(),
                ),
              );
            },
          ),
          // Новая кнопка фильтрации клиентов по просрочке
          IconButton(
            icon: Icon(
              showOnlySleeping
                  ? Icons.warning_rounded
                  : Icons.warning_amber_rounded,
              // Если фильтр включен — красим его в акцентный цвет (например, оранжевый или primary)
              color: showOnlySleeping ? Colors.orange.shade700 : null,
            ),
            tooltip: showOnlySleeping
                ? 'Показать всех'
                : 'Только просроченные клиенты',
            onPressed: () =>
                context.read<ClientsProvider>().toggleSleepingFilter(),
          ),
          VerticalDivider(
            thickness: 2, // Толщина линии
            width: 20, // Отступы вокруг линии (общая ширина виджета)
            indent: 10, // Отступ сверху
            endIndent: 10, // Отступ снизу
          ),
          const LocaleToggleButton(),
          const ThemeToggleButton(),
        ],
      ),
      body: switch (status) {
        DeliveryStatus.initial || DeliveryStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        DeliveryStatus.failure => _ErrorView(),
        DeliveryStatus.success => _Dashboard(
          scrollController: _scrollController,
        ),
      },
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

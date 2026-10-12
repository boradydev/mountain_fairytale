import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_screen.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/features/dashboard/ui/dashboard_screen.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_screen.dart';
import 'package:mountain_fairytale/features/sales_representative_commissions/ui/sales_analytics_screen.dart';
import 'package:mountain_fairytale/shared/widgets/account_menu_button.dart';
import 'package:mountain_fairytale/shared/widgets/theme_toggle_button.dart';
import 'package:provider/provider.dart';

/// Общая навигация основных разделов. Вкладки создаются при первом открытии
/// и сохраняют своё состояние до завершения пользовательской сессии.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final Set<int> _visitedSections = {0};

  static const _screens = <Widget>[
    DeliveryDaysScreen(),
    SalesRepresentativeCommissionScreen(),
    AuditLogScreen(),
    EmployeesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAdmin = context.select(
      (AuthProvider provider) => provider.currentUser?.isAdmin == true,
    );
    final sectionCount = isAdmin ? _screens.length : _screens.length - 1;
    if (!isAdmin) {
      _visitedSections.remove(3);
      if (_selectedIndex >= sectionCount) _selectedIndex = 0;
    }

    return DefaultTabController(
      key: ValueKey(isAdmin),
      initialIndex: _selectedIndex,
      length: sectionCount,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: false,
          titleSpacing: 12,
          title: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(vertical: 8),
            indicator: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: colors.onSecondaryContainer,
            unselectedLabelColor: colors.onSurfaceVariant,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
                _visitedSections.add(index);
              });
            },
            tabs: [
              const Tab(text: 'Дашборд'),
              const Tab(text: 'Вознаграждения'),
              const Tab(text: 'Журнал событий'),
              if (isAdmin) const Tab(text: 'Сотрудники'),
            ],
          ),
          actions: const [
            AccountMenuButton(),
            ThemeToggleButton(),
            SizedBox(width: 12),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            for (var index = 0; index < sectionCount; index++)
              TickerMode(
                enabled: index == _selectedIndex,
                child: ExcludeFocus(
                  excluding: index != _selectedIndex,
                  child: _visitedSections.contains(index)
                      ? _screens[index]
                      : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

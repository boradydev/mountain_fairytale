import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_button.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_button.dart';
import 'package:mountain_fairytale/features/audit_event/ui/audit_event_screen.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/features/dashboard/ui/dashboard_screen.dart';
import 'package:mountain_fairytale/features/employees/ui/employees_screen.dart';
import 'package:mountain_fairytale/features/commissions/ui/commissions_screen.dart';
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
    CommissionsScreen(),
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
            indicatorPadding: EdgeInsets.zero,
            indicator: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              border: Border(
                bottom: BorderSide(color: colors.primary, width: 2),
              ),
            ),
            splashBorderRadius: BorderRadius.zero,
            overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.pressed)) {
                return colors.primary.withValues(alpha: 0.10);
              }
              if (states.contains(WidgetState.focused)) {
                return colors.primary.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.hovered)) {
                return colors.primary.withValues(alpha: 0.04);
              }
              return null;
            }),
            labelColor: colors.primary,
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
              const Tab(text: 'Комиссии'),
              const Tab(text: 'Журнал событий'),
              if (isAdmin) const Tab(text: 'Сотрудники'),
            ],
          ),
          actions: const [
            ServerSettingsButton(),
            UpdateButton(),
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

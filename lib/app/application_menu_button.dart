import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mountain_fairytale/features/app_settings/ui/server_settings_button.dart';
import 'package:mountain_fairytale/features/app_compatibility/ui/app_compatibility_provider.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_provider.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_button.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_provider.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

/// Application actions shared by the main, login and server-unavailable screens.
class ApplicationMenuButton extends StatelessWidget {
  const ApplicationMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ServerSettingsProvider?>();
    final updates = context.watch<UpdateProvider?>();
    final compatibility = context.watch<AppCompatibilityProvider?>();
    if (settings == null && updates == null) return const SizedBox.shrink();
    return MenuAnchor(
      menuChildren: [
        if (compatibility?.installed != null)
          MenuItemButton(
            child: Text(
              'Приложение: ${compatibility!.installed!.version}+${compatibility.installed!.build}',
            ),
          ),
        if (compatibility?.backendVersion != null)
          MenuItemButton(
            child: Text(
              'Сервер: ${compatibility!.backendVersion}; требуется приложение ≥ ${compatibility.minimumVersion}',
            ),
          ),
        if (settings != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.dns_outlined),
            onPressed: () => ServerSettingsButton.open(context, settings),
            child: const Text('Настройки подключения…'),
          ),
        if (updates != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.system_update_alt),
            onPressed: updates.checking
                ? null
                : () => UpdateButton.open(context, updates),
            child: const Text('Проверить обновления…'),
          ),
      ],
      builder: (context, controller, _) => Badge(
        isLabelVisible: updates?.available != null,
        child: AppIconButton(
          icon: Icons.more_vert,
          tooltip: updates?.available == null
              ? 'Приложение'
              : 'Приложение: доступно обновление',
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else if (!Navigator.of(context, rootNavigator: true).canPop()) {
              controller.open();
            }
          },
        ),
      ),
    );
  }
}

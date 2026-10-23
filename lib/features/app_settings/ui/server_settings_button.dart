import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mountain_fairytale/core/utils/scaffold_messenger_key.dart';
import 'package:mountain_fairytale/features/auth/auth_abcs.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_provider.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

class ServerSettingsButton extends StatelessWidget {
  const ServerSettingsButton({super.key});

  Future<void> _open(
    BuildContext context,
    ServerSettingsProvider settings,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    // Editors and other modal operations must be closed before switching servers.
    if (navigator.canPop()) return;
    final auth = context.read<AuthService>();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => ServerSettingsDialog(settings: settings),
    );
    if (url == null || !context.mounted) return;
    try {
      await settings.changeUrl(url, endSession: auth.logout);
    } catch (_) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Адрес не изменён. Не удалось очистить сохранённый вход или записать настройки. Повторите попытку.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ServerSettingsProvider?>();
    if (settings == null) return const SizedBox.shrink();
    return AppIconButton(
      icon: Icons.settings_outlined,
      tooltip: 'Настройки приложения',
      onPressed: () => _open(context, settings),
    );
  }
}

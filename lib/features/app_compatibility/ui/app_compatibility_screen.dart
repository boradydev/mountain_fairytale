import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:mountain_fairytale/app/application_menu_button.dart';
import 'package:mountain_fairytale/features/app_compatibility/ui/app_compatibility_provider.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_button.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_provider.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/theme_toggle_button.dart';

class AppCompatibilityScreen extends StatelessWidget {
  const AppCompatibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compatibility = context.watch<AppCompatibilityProvider>();
    final updates = context.watch<UpdateProvider?>();
    final required = compatibility.status == CompatibilityStatus.updateRequired;
    final installed = compatibility.installed;
    return Scaffold(
      appBar: AppBar(
        actions: const [ApplicationMenuButton(), ThemeToggleButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  required ? Icons.system_update_alt : Icons.cloud_off,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  required ? 'Требуется обновление' : 'Проверка совместимости',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (compatibility.checking)
                  const CircularProgressIndicator()
                else
                  Text(
                    compatibility.error ?? 'Проверяем версию приложения…',
                    textAlign: TextAlign.center,
                  ),
                if (required) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Несохранённые данные форм сброшены. После обновления создайте документы заново.',
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                if (installed != null)
                  Text('Приложение: ${installed.version}+${installed.build}'),
                if (compatibility.backendVersion != null)
                  Text('Сервер: ${compatibility.backendVersion}'),
                if (compatibility.minimumVersion != null)
                  Text(
                    'Требуется приложение: ${compatibility.minimumVersion} или новее',
                  ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (updates != null)
                      AppPrimaryButton(
                        text: 'Обновить приложение',
                        onPressed: updates.checking
                            ? null
                            : () => UpdateButton.open(context, updates),
                      ),
                    AppSecondaryButton(
                      text: 'Повторить проверку',
                      onPressed: compatibility.checking
                          ? null
                          : compatibility.check,
                    ),
                    AppSecondaryButton(
                      text: 'Закрыть приложение',
                      onPressed: () => windowManager.destroy(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

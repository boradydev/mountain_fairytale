import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/features/app_updates/update_service.dart';
import 'package:mountain_fairytale/features/app_updates/ui/update_provider.dart';

/// One feature-specific entry point, reused on the login and main screens.
class UpdateButton extends StatelessWidget {
  const UpdateButton({super.key});

  static Future<void> open(BuildContext context, UpdateProvider updates) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    // Never replace an editor, modal form or an outstanding navigation route.
    if (navigator.canPop()) return;
    await updates.check();
    if (!context.mounted || navigator.canPop()) return;
    final release = updates.available;
    if (!updates.ready || updates.error != null || release == null) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Версия ${updates.installedVersion}'),
          content: Text(
            updates.error ??
                (updates.ready
                    ? 'Новых обновлений нет.'
                    : 'Обновления не настроены в этой сборке.'),
          ),
          actions: [
            AppIconButton(
              icon: Icons.close,
              tooltip: 'Закрыть',
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ],
        ),
      );
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Обновление ${release.version}',
      content:
          '${release.description}\n\n'
          'Сохраните работу и закройте другие экземпляры приложения. '
          'После загрузки и подтверждения установки приложение закроется. '
          'Настройки и авторизация сохранятся.',
      confirmText: 'Обновить',
      cancelText: 'Позже',
    );
    if (!confirmed || !context.mounted || navigator.canPop()) return;

    // Keep the app read-only while the native updater is downloading and
    // awaiting confirmation. It is now safe for can_shutdown to return true.
    final barrier = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('Обновление приложения'),
          content: Text(
            'Продолжите в окне обновления. Чтобы вернуться к работе, '
            'закройте окно обновления или нажмите «Позже».',
          ),
        ),
      ),
    );
    navigator.push(barrier);
    var closing = false;
    void releaseBarrier() {
      if (!closing && barrier.isActive) navigator.removeRoute(barrier);
    }

    UpdateService.channel.setMethodCallHandler((call) async {
      if (call.method == 'shutdown') {
        // Authentication/navigation can change while a download is in flight.
        // Never close an app after losing the modal work barrier. Setup also
        // refuses to touch files while the application's mutex is present.
        if (!navigator.mounted || !barrier.isActive || !barrier.isCurrent) {
          return;
        }
        closing = true;
        // No logout: refresh tokens and preferences remain in the user profile.
        await windowManager.destroy();
      } else if (call.method == 'dismissed') {
        releaseBarrier();
      }
    });
    try {
      await updates.service.checkWithUi();
    } catch (_) {
      releaseBarrier();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось запустить обновление. Попробуйте ещё раз.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final updates = context.watch<UpdateProvider?>();
    if (updates == null) return const SizedBox.shrink();
    return Badge(
      isLabelVisible: updates.available != null,
      child: AppIconButton(
        icon: Icons.system_update_alt,
        tooltip: updates.available == null
            ? 'Проверить обновления'
            : 'Доступна версия ${updates.available!.version}',
        onPressed: updates.checking ? null : () => open(context, updates),
      ),
    );
  }
}

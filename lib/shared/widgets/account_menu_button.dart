import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/features/auth/ui/change_password_dialog.dart';
import 'package:provider/provider.dart';

/// Действия учётной записи в общей верхней панели приложения.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final username = auth.currentUser?.username ?? 'Учётная запись';
    final showUsername = MediaQuery.sizeOf(context).width >= 800;

    return PopupMenuButton<String>(
      tooltip: username,
      enabled: !auth.isLoading,
      onSelected: (value) async {
        switch (value) {
          case 'logout':
            await auth.logout();
          case 'password':
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
      itemBuilder: (_) => [
        PopupMenuItem<String>(enabled: false, child: Text(username)),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'password', child: Text('Изменить пароль')),
        const PopupMenuItem(value: 'logout', child: Text('Выйти')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined),
            if (showUsername) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(username, overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

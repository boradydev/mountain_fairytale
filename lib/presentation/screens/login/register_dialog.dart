import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/auth_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class RegisterDialog extends StatefulWidget {
  const RegisterDialog({
    super.key,
  });

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      return;
    }

    final success = await context.read<AuthProvider>().register(
      username: username,
      password: password,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    final error = context.read<AuthProvider>().error;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AlertDialog(
      title: const Text('Регистрация'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameController,
              enabled: !auth.isRegistering,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Логин',
              ),
              onSubmitted: (_) => _register(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              enabled: !auth.isRegistering,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                helperText: 'Можно оставить пустым',
              ),
              onSubmitted: (_) => _register(),
            ),
          ],
        ),
      ),
      actions: [
        AppSecondaryButton(
          text: 'Отмена',
          onPressed: auth.isRegistering
              ? null
              : () => Navigator.of(context).pop(),
        ),
        AppPrimaryButton(
          text: 'Зарегистрировать',
          onPressed: auth.isRegistering ? null : _register,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/auth_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/base_form_dialog_widget.dart';
import 'package:provider/provider.dart';

class RegisterDialog extends StatefulWidget {
  const RegisterDialog({
    super.key,
  });

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

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

    return BaseFormDialog(
      title: 'Регистрация',
      submitButtonText: 'Зарегистрировать',
      formKey: _formKey,
      onSubmit: _register,
      // В BaseFormDialog обычно есть кнопка отмены или мы можем добавить её в children,
      // но для соответствия ClientDialog используем стандартный submit.
      // Если нужно добавить кнопку "Отмена" как в оригинальном AlertDialog,
      // можно добавить её в список children или через кастомный экшен.
      children: [
        TextFormField(
          controller: _usernameController,
          enabled: !auth.isRegistering,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Логин',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите логин';
            }
            return null;
          },
          onFieldSubmitted: (_) => _register(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          enabled: !auth.isRegistering,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Пароль',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
            helperText: 'Можно оставить пустым',
          ),
          onFieldSubmitted: (_) => _register(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

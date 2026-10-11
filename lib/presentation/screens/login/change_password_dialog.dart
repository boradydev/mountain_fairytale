import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.isChangingPassword || !_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final changed = await auth.changePassword(password: _password.text);
    if (!mounted) return;
    if (changed) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = auth.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isChangingPassword;
    return PopScope(
      canPop: !loading,
      child: AlertDialog(
        title: const Text('Изменить пароль'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _password,
                  enabled: !loading,
                  obscureText: true,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль',
                    helperText: 'Можно оставить пустым',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmation,
                  enabled: !loading,
                  obscureText: true,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Повторите пароль',
                  ),
                  validator: (value) =>
                      value == _password.text ? null : 'Пароли не совпадают',
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (loading) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: loading ? null : () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: loading ? null : _submit,
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

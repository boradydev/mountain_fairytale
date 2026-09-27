import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mountain_fairytale/presentation/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    final provider = context.read<AuthProvider>();

    final success = await provider.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted || success) {
      return;
    }

    final error = provider.error;

    if (error == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Авторизация',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _usernameController,
                    enabled: !provider.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Логин',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    enabled: !provider.isLoading,
                    obscureText: true,
                    onSubmitted: (_) => _login(),
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: provider.isLoading ? null : _login,
                      child: provider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Войти'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

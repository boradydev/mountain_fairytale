import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/providers/auth_provider.dart';
import 'package:mountain_fairytale/presentation/providers/theme_provider.dart';
import 'package:mountain_fairytale/presentation/screens/login/register_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();

  String? _selectedUsername;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;
      context.read<AuthProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _login() async {
    final username = _selectedUsername;

    if (username == null || username.isEmpty) {
      return;
    }

    final success = await context.read<AuthProvider>().login(
      username: username,
      password: _passwordController.text,
    );

    if (!mounted || success) {
      return;
    }

    final error = context.read<AuthProvider>().error;

    if (error == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
      ),
    );
  }

  Future<void> _openRegisterDialog() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const RegisterDialog(),
    );

    if (!mounted) {
      return;
    }

    final auth = context.read<AuthProvider>();

    if (auth.users.isNotEmpty && _selectedUsername == null) {
      setState(() {
        _selectedUsername = auth.users.first.username;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final users = auth.users;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Авторизация'),
        actions: [
          IconButton(
            tooltip: themeProvider.isDarkMode ? 'Светлая тема' : 'Тёмная тема',
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              context.read<ThemeProvider>().toggleTheme();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Добро пожаловать',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Войдите в Mountain Fairytale',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUsername,
                  decoration: const InputDecoration(
                    labelText: 'Пользователь',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                  ),
                  items: users
                      .map(
                        (user) => DropdownMenuItem<String>(
                          value: user.username,
                          child: Text(user.username),
                        ),
                      )
                      .toList(),
                  onChanged: auth.isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _selectedUsername = value;
                          });
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  enabled: !auth.isLoading,
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(
                        text: 'Зарегистрировать',
                        onPressed: auth.isLoading ? null : _openRegisterDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppPrimaryButton(
                        text: 'Войти',
                        onPressed: auth.isLoading ? null : _login,
                      ),
                    ),
                  ],
                ),
                if (auth.isLoading) ...[
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

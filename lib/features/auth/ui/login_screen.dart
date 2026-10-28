import 'package:flutter/material.dart';
import 'package:mountain_fairytale/app/application_menu_button.dart';
import 'package:mountain_fairytale/features/auth/ui/auth_provider.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/theme_toggle_button.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  String? _selectedUsername;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<AuthProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final username = _selectedUsername;
    if (auth.isLoading ||
        auth.isLoadingUsers ||
        username == null ||
        !auth.users.any((user) => user.username == username)) {
      return;
    }
    final success = await auth.login(
      username: username,
      password: _passwordController.text,
    );
    if (mounted && success) {
      _passwordController.clear();
      setState(() => _obscurePassword = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final users = auth.users;
    final selected = users.any((user) => user.username == _selectedUsername)
        ? _selectedUsername
        : null;
    final canLogin =
        !auth.isLoading &&
        !auth.isLoadingUsers &&
        auth.usersError == null &&
        selected != null;
    final passwordHelp =
        auth.error ?? 'Если пароль не установлен, оставьте поле пустым';
    final helperFontSize =
        Theme.of(context).textTheme.bodySmall?.fontSize ?? 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Авторизация'),
        actions: const [
          ApplicationMenuButton(),
          ThemeToggleButton(),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                const Text('Войдите в Mountain Fairytale'),
                const SizedBox(height: 32),
                if (auth.isLoadingUsers) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  const Text('Загрузка пользователей…'),
                  const SizedBox(height: 16),
                ],
                if (!auth.isLoadingUsers && auth.usersError != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: MaterialBanner(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHigh,
                      leading: Icon(
                        Icons.cloud_off_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      content: Text(auth.usersError!),
                      contentTextStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      forceActionsBelow: true,
                      actions: [
                        TextButton(
                          onPressed: auth.loadUsers,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else if (!auth.isLoadingUsers && users.isEmpty) ...[
                  const Text(
                    'Нет активных пользователей. Обратитесь к администратору.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: auth.loadUsers,
                    child: const Text('Обновить список'),
                  ),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<String>(
                  key: ValueKey(selected),
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Пользователь',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: users
                      .map(
                        (user) => DropdownMenuItem(
                          value: user.username,
                          child: Text(user.username),
                        ),
                      )
                      .toList(),
                  onChanged: auth.isLoading || auth.isLoadingUsers
                      ? null
                      : (value) {
                          auth.clearLoginError();
                          setState(() {
                            _selectedUsername = value;
                            _passwordController.clear();
                            _obscurePassword = true;
                          });
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  enabled: !auth.isLoading,
                  obscureText: _obscurePassword,
                  maxLength: 50,
                  onChanged: (_) => auth.clearLoginError(),
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: AppIconButton(
                      icon: _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      tooltip: _obscurePassword
                          ? 'Показать пароль'
                          : 'Скрыть пароль',
                      onPressed: auth.isLoading
                          ? null
                          : () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                              _passwordFocus.requestFocus();
                            },
                    ),
                    helper: Tooltip(
                      message: passwordHelp,
                      child: SizedBox(
                        height:
                            MediaQuery.textScalerOf(context)
                                .scale(helperFontSize) *
                            2.8,
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            passwordHelp,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  height: 1.4,
                                  color: auth.error == null
                                      ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                      : Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    text: 'Войти',
                    onPressed: canLogin ? _login : null,
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: auth.isLoading
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

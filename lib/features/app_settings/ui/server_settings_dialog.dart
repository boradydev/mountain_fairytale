import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/app_settings/data/server_settings_repository.dart';
import 'package:mountain_fairytale/features/app_settings/ui/server_settings_provider.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

class ServerSettingsDialog extends StatefulWidget {
  final ServerSettingsProvider settings;
  final bool initiallyEditable;
  const ServerSettingsDialog({
    super.key,
    required this.settings,
    this.initiallyEditable = true,
  });

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  final _form = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.settings.url);
  bool _busy = false;
  bool _checking = false;
  ServerConnectionResult? _result;
  String? _checkedUrl;
  late bool _editing = widget.initiallyEditable;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    try {
      normalizeServerUrl(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  Future<void> _check({bool save = false}) async {
    if (_busy || !_form.currentState!.validate()) return;
    final url = normalizeServerUrl(_controller.text);
    if (save && url == widget.settings.url) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = true;
      _checking = true;
    });
    try {
      final result = save && _checkedUrl == url && _result != null
          ? _result!
          : await widget.settings.check(url);
      if (!mounted) return;
      setState(() {
        _result = result;
        _checkedUrl = url;
        _checking = false;
      });
      if (!save) return;
      if (!result.available) {
        final confirmed = await ConfirmDialog.show(
          context,
          title: 'Сервер недоступен',
          content:
              '${result.message}\n\nСохранить адрес всё равно? Подключиться можно будет после запуска сервера.',
          confirmText: 'Сохранить всё равно',
        );
        if (!mounted || !confirmed) return;
      }
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Сменить сервер?',
        content: 'При смене сервера потребуется войти заново. Загруженные данные и несохранённые изменения текущей сессии будут сброшены.',
        confirmText: widget.initiallyEditable
            ? 'Сменить сервер'
            : 'Сменить сервер и выйти',
      );
      if (mounted && confirmed) Navigator.of(context).pop(url);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Настройки подключения'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _controller,
                enabled: _editing && !_busy,
                readOnly: !_editing,
                validator: _validate,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'Адрес сервера',
                  hintText: 'http://192.168.0.25:8000',
                  helperText: 'Адрес с портом, без /app/v1 и других путей.',
                  helperMaxLines: 2,
                  errorMaxLines: 3,
                  prefixIcon: Icon(Icons.dns_outlined),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {
                  _result = null;
                  _checkedUrl = null;
                }),
              ),
              const SizedBox(height: 12),
              if (_editing)
                AppSecondaryButton(
                  text: 'Вернуть адрес по умолчанию',
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _controller.text = widget.settings.defaultUrl;
                            _result = null;
                            _checkedUrl = null;
                          });
                        },
                ),
              const SizedBox(height: 16),
              if (_checking) const LinearProgressIndicator(),
              if (_result != null) ...[
                const SizedBox(height: 8),
                Text(
                  _result!.message,
                  style: TextStyle(
                    color: _result!.available
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Адрес сохраняется на этом компьютере. При смене сервера потребуется войти заново.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      AppSecondaryButton(
        text: 'Проверить соединение',
        onPressed: _busy ? null : _check,
      ),
      AppSecondaryButton(
        text: _editing ? 'Отмена' : 'Закрыть',
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
      ),
      AppPrimaryButton(
        text: _editing ? 'Сохранить' : 'Сменить сервер и выйти…',
        onPressed: _busy
            ? null
            : () {
                if (_editing) {
                  _check(save: true);
                } else {
                  setState(() => _editing = true);
                }
              },
      ),
    ],
  );
}

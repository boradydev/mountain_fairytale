import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/clients/data/clients_model.dart';
import 'package:mountain_fairytale/features/clients/ui/clients_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:provider/provider.dart';

class ClientDialog extends StatefulWidget {
  final Client? client;
  const ClientDialog({super.key, this.client});
  bool get isEditMode => client != null;
  @override
  State<ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<ClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _threshold;
  late final TextEditingController _cooldown;
  DateTime? _cooldownDate;
  final _focusNodes = List.generate(3, (_) => FocusNode());
  bool _busy = false;
  bool _checking = false;
  bool _loadingDirectories = true;
  String? _error;
  String? _directoryError;
  String? _phoneError;
  String? _checkedInput;
  int _checkVersion = 0;
  Client? _duplicate;
  String? _salesRepId;
  String? _paymentMethodId;
  List<ClientDirectoryEntry> _salesReps = [];
  List<ClientDirectoryEntry> _paymentMethods = [];
  String get _input =>
      [_name.text.trim(), _phone.text.trim(), _address.text.trim()].join('\n');

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _name = TextEditingController(text: client?.name ?? '');
    _phone = TextEditingController(text: client?.phone ?? '');
    _address = TextEditingController(text: client?.address ?? '');
    _threshold = TextEditingController(
      text: client?.sleepingThresholdDays.toString() ?? '7',
    );
    _cooldownDate = client?.cooldownUntil;
    _cooldown = TextEditingController(text: _cooldownLabel(_cooldownDate));
    _salesRepId = client?.salesRepresentativeId;
    _paymentMethodId = client?.defaultPaymentMethodId;
    _salesReps = _withCurrent([], _salesRepId, client?.salesRepresentativeName);
    _paymentMethods = _withCurrent(
      [],
      _paymentMethodId,
      client?.defaultPaymentMethodName,
    );
    for (final focus in _focusNodes) {
      focus.addListener(() {
        if (!focus.hasFocus && !_busy) _checkDuplicate();
      });
    }
    for (final controller in [_name, _phone, _address]) {
      controller.addListener(() {
        _checkVersion++;
        setState(() {
          _duplicate = null;
          _checkedInput = null;
          _checking = false;
        });
      });
    }
    _phone.addListener(() {
      setState(() => _phoneError = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDirectories());
  }

  List<ClientDirectoryEntry> _withCurrent(
    List<ClientDirectoryEntry> rows,
    String? id,
    String? name,
  ) {
    if (id == null || rows.any((row) => row.id == id)) return rows;
    return [
      ...rows,
      ClientDirectoryEntry(
        id,
        '${name ?? 'Недоступная запись'} (текущее значение)',
        isActive: false,
      ),
    ];
  }

  Future<void> _loadDirectories() async {
    setState(() {
      _loadingDirectories = true;
      _directoryError = null;
    });
    try {
      final provider = context.read<ClientsProvider>();
      final reps = await provider.getSalesRepresentatives();
      final methods = await provider.getPaymentMethods();
      if (!mounted) return;
      setState(() {
        _salesReps = _withCurrent(
          reps,
          widget.client?.salesRepresentativeId,
          widget.client?.salesRepresentativeName,
        );
        _paymentMethods = _withCurrent(
          methods,
          widget.client?.defaultPaymentMethodId,
          widget.client?.defaultPaymentMethodName,
        );
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _directoryError =
              'Не удалось загрузить справочники. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingDirectories = false);
    }
  }

  Future<bool> _checkDuplicate() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        _name.text.trim().length > 120 ||
        _phone.text.trim().length > 32 ||
        _address.text.trim().length > 500) {
      return false;
    }
    final input = _input;
    if (_checkedInput == input) return true;
    final version = ++_checkVersion;
    setState(() {
      _checking = true;
      _checkedInput = null;
      _error = null;
    });
    try {
      final match = await context.read<ClientsProvider>().checkClientDuplicate(
        _name.text.trim(),
        _phone.text.trim(),
        _address.text.trim(),
      );
      if (!mounted || version != _checkVersion) return false;
      setState(() {
        _checking = false;
        _checkedInput = input;
        _duplicate = match?.id == widget.client?.id ? null : match;
      });
      return true;
    } catch (_) {
      if (mounted && version == _checkVersion) {
        setState(() {
          _checking = false;
          _error = 'Не удалось проверить похожих клиентов. Повторите попытку.';
        });
      }
      return false;
    }
  }

  String _cooldownLabel(DateTime? value) {
    if (value == null) return '';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _pickCooldown() async {
    final initial = _cooldownDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year < 2000 ? initial.year : 2000),
      lastDate: DateTime(initial.year > 2100 ? initial.year : 2100, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _cooldownDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _cooldown.text = _cooldownLabel(_cooldownDate);
    });
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final provider = context.read<ClientsProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!widget.isEditMode) {
        if (!await _checkDuplicate() || !mounted) return;
        if (_duplicate != null) {
          final confirmed = await ConfirmDialog.show(
            context,
            title: 'Найден похожий клиент',
            content:
                '${_duplicate!.name} — ${_duplicate!.isActive ? 'Активен' : 'Неактивен'}\n${_duplicate!.phone}\n${_duplicate!.address}\nСоздать нового клиента?',
            confirmText: 'Создать нового',
          );
          if (!confirmed || !mounted) return;
        }
      }
      final cooldown = _cooldownDate;
      final success = widget.isEditMode
          ? await provider.updateClient(
              clientId: widget.client!.id,
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              address: _address.text.trim(),
              thresholdDays: int.parse(_threshold.text.trim()),
              salesRepId: _salesRepId,
              paymentMethodId: _paymentMethodId,
              cooldownUntil: cooldown,
            )
          : await provider.addClient(
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              address: _address.text.trim(),
              thresholdDays: int.parse(_threshold.text.trim()),
              salesRepId: _salesRepId,
              paymentMethodId: _paymentMethodId,
              cooldownUntil: cooldown,
            );
      if (!mounted) return;
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _phoneError = provider.phoneError;
          _error = provider.errorMessage.isEmpty ? null : provider.errorMessage;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActive(Client client, bool active) async {
    if (_busy) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: active ? 'Активировать клиента?' : 'Деактивировать клиента?',
      content: active
          ? '«${client.name}» снова станет доступен.'
          : '«${client.name}» станет недоступен для новых маршрутов. Запись и история сохранятся.',
      confirmText: active ? 'Активировать' : 'Деактивировать',
      destructive: !active,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final provider = context.read<ClientsProvider>();
    final success = await provider.setClientActive(client.id, active);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = provider.errorMessage;
      });
    }
  }

  @override
  void dispose() {
    _checkVersion++;
    for (final controller in [_name, _phone, _address, _threshold, _cooldown]) {
      controller.dispose();
    }
    for (final focus in _focusNodes) {
      focus.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int? maxLength,
    FocusNode? focus,
    String? hint,
    String? Function(String?)? validator,
    String? error,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      focusNode: focus,
      enabled: !_busy,
      maxLength: maxLength,
      keyboardType: keyboardType,
      forceErrorText: error,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty
              ? 'Заполните поле'
              : value.trim().length > maxLength!
              ? 'Не более $maxLength символов'
              : null,
    ),
  );

  Widget _directory(
    String label,
    List<ClientDirectoryEntry> rows,
    String? id,
    ValueChanged<String?> onChanged,
    IconData icon,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: AppDropdown<String>(
      label: label,
      items: [
        '',
        ...rows
            .where((row) => row.isActive || row.id == id)
            .map((row) => row.id),
      ],
      value: id ?? '',
      enabled: !_busy && !_loadingDirectories && _directoryError == null,
      prefixIcon: icon,
      itemLabelBuilder: (id) => id.isEmpty
          ? 'Не выбран'
          : rows.firstWhere((row) => row.id == id).name,
      onChanged: (id) => onChanged(id == null || id.isEmpty ? null : id),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: BaseFormDialog(
      title: widget.isEditMode
          ? 'Редактирование клиента'
          : 'Добавление клиента',
      submitButtonText: widget.isEditMode ? 'Сохранить' : 'Добавить',
      formKey: _formKey,
      onSubmit: _save,
      isBusy: _busy,
      leadingAction: widget.client == null
          ? null
          : AppIconButton(
              icon: widget.client!.isActive
                  ? Icons.archive_outlined
                  : Icons.restore,
              tooltip: widget.client!.isActive
                  ? 'Деактивировать клиента'
                  : 'Активировать клиента',
              destructive: widget.client!.isActive,
              onPressed: _busy
                  ? null
                  : () => _setActive(widget.client!, !widget.client!.isActive),
            ),
      children: [
        if (_busy || _loadingDirectories) const LinearProgressIndicator(),
        if (widget.client != null && !widget.client!.isActive)
          const Text('Клиент деактивирован'),
        DuplicateCheckStatusWidget(
          isChecking: _checking,
          isChecked: _checkedInput != null,
          hasDuplicate: _duplicate != null,
          warningText: _duplicate == null
              ? ''
              : 'Найден похожий клиент: ${_duplicate!.name} — ${_duplicate!.isActive ? 'Активен' : 'Неактивен'}\n${_duplicate!.phone}\n${_duplicate!.address}',
          expandedChild: _duplicate != null && !_duplicate!.isActive
              ? AppSecondaryButton(
                  text: 'Активировать существующего',
                  onPressed: _busy ? null : () => _setActive(_duplicate!, true),
                )
              : null,
        ),
        const SizedBox(height: 8),
        _field(
          _name,
          'Название организации / ФИО *',
          Icons.person_outline,
          maxLength: 120,
          focus: _focusNodes[0],
        ),
        _field(
          _address,
          'Адрес доставки *',
          Icons.location_on_outlined,
          maxLength: 500,
          focus: _focusNodes[2],
        ),
        _field(
          _phone,
          'Номер телефона *',
          Icons.phone_outlined,
          maxLength: 32,
          focus: _focusNodes[1],
          hint: '+7 (XXX) XXX-XX-XX',
          error: _phoneError,
          keyboardType: TextInputType.phone,
        ),
        _field(
          _threshold,
          'Порог засыпания (в днях) *',
          Icons.hourglass_empty_rounded,
          keyboardType: TextInputType.number,
          validator: (value) {
            final days = int.tryParse(value?.trim() ?? '');
            return days == null || days < 0 || days > 3650
                ? 'Введите целое число от 0 до 3650'
                : null;
          },
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: _cooldown,
            readOnly: true,
            enabled: !_busy,
            onTap: _pickCooldown,
            decoration: InputDecoration(
              labelText: 'Отсрочка до',
              hintText: 'Выберите дату и время',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.event_outlined),
              suffixIcon: _cooldownDate == null
                  ? null
                  : AppIconButton(
                      icon: Icons.clear,
                      tooltip: 'Снять отсрочку',
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _cooldownDate = null;
                              _cooldown.clear();
                            }),
                    ),
            ),
          ),
        ),
        if (_directoryError != null) ...[
          Text(
            _directoryError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          AppSecondaryButton(
            text: 'Повторить загрузку',
            onPressed: _busy ? null : _loadDirectories,
          ),
        ],
        _directory(
          'Торговый представитель',
          _salesReps,
          _salesRepId,
          (id) => setState(() => _salesRepId = id),
          Icons.badge_outlined,
        ),
        _directory(
          'Способ оплаты по умолчанию',
          _paymentMethods,
          _paymentMethodId,
          (id) => setState(() => _paymentMethodId = id),
          Icons.payments_outlined,
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}

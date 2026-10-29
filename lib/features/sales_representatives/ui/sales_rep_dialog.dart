import 'package:mountain_fairytale/core/state/form_editing.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/shared/widgets/russian_phone_input_formatter.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/app_notify.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_model.dart';
import 'package:mountain_fairytale/features/sales_representatives/ui/sales_representative_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:provider/provider.dart';

Future<bool> confirmSalesRepresentativeActivity(
  BuildContext context, {
  required String name,
  required bool active,
}) => ConfirmDialog.show(
  context,
  title: active
      ? 'Активировать представителя?'
      : 'Деактивировать представителя?',
  content:
      '«$name». Закрепления клиентов и исторические начисления сохранятся.',
  confirmText: active ? 'Активировать' : 'Деактивировать',
  destructive: !active,
);

class SalesRepDialog extends StatefulWidget {
  final SalesRepresentative? salesRep;
  final bool directoryMode;
  final ApiSalesRepresentative? apiSalesRep;
  final SalesRepresentativeApiRepository? apiRepository;
  final ValueChanged<ApiSalesRepresentative>? onOpenSalesRep;

  const SalesRepDialog({
    super.key,
    this.salesRep,
    this.directoryMode = false,
    this.apiSalesRep,
    this.apiRepository,
    this.onOpenSalesRep,
  });

  @override
  State<SalesRepDialog> createState() => _SalesRepDialogState();
}

class _SalesRepDialogState extends State<SalesRepDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _commissionPercentController;

  final _nameFocusNode = FocusNode();

  bool _isCheckingDuplicate = false;
  bool _duplicateChecked = false;
  SalesRepresentative? _duplicateRep;
  ApiSalesRepresentative? _apiDuplicate;
  bool _busy = false;
  String? _error;
  String? _phoneError;
  String? _checkedApiInput;
  int _checkVersion = 0;
  bool get _apiMode => widget.apiRepository != null;

  bool get _isEditMode => widget.salesRep != null || widget.apiSalesRep != null;

  late final Map<String, Object?> _originalValues;
  late final String _originalDuplicateInput;
  late final DuplicateCheckCoordinator _duplicateCheck;
  String get _normalizedPhone =>
      _apiMode || RussianPhoneInputFormatter.isComplete(_phoneController.text)
      ? RussianPhoneInputFormatter.toApiPhone(_phoneController.text)
      : _phoneController.text.trim();
  Map<String, Object?> get _values => {
    'name': _nameController.text.trim(),
    'phone': _normalizedPhone,
    'commissionPercent':
        formNumber(_commissionPercentController.text) ??
        _commissionPercentController.text.trim(),
  };
  Map<String, Object?> get _changes =>
      changedFormFields(_originalValues, _values);
  String get _duplicateInput =>
      _apiMode ? _apiInput : _nameController.text.trim();
  bool get _needsDuplicateCheck =>
      !_isEditMode || _duplicateInput != _originalDuplicateInput;
  bool get _validDuplicateInput =>
      _nameController.text.trim().isNotEmpty &&
      _nameController.text.trim().length <= 120 &&
      (!_apiMode ||
          RussianPhoneInputFormatter.isComplete(_phoneController.text));
  void _refreshForm() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();

    final salesRep = widget.salesRep;

    _nameController = TextEditingController(
      text: widget.apiSalesRep?.name ?? salesRep?.name ?? '',
    );

    _phoneController = TextEditingController(
      text: _apiMode
          ? RussianPhoneInputFormatter.format(widget.apiSalesRep?.phone ?? '')
          : salesRep?.phone ?? '',
    );

    _commissionPercentController = TextEditingController(
      text:
          widget.apiSalesRep?.commissionPercent.toString() ??
          salesRep?.commissionPercent.toString() ??
          '',
    );

    _originalValues = Map.of(_values);
    _originalDuplicateInput = _duplicateInput;
    _duplicateCheck = DuplicateCheckCoordinator(_duplicateInput);
    for (final controller in [_nameController, _phoneController]) {
      controller.addListener(_onDuplicateInputChanged);
    }
    _commissionPercentController.addListener(_refreshForm);
  }

  void _onDuplicateInputChanged() {
    final changed = _duplicateCheck.inputChanged(
      _duplicateInput,
      canCheck: _needsDuplicateCheck && _validDuplicateInput,
      check: _checkDuplicate,
    );
    setState(() {
      if (changed) {
        _checkVersion++;
        _apiDuplicate = null;
        _duplicateRep = null;
        _checkedApiInput = null;
        _duplicateChecked = false;
        _isCheckingDuplicate = false;
      }
      _phoneError = null;
      _error = null;
    });
  }

  Future<bool> _checkDuplicate() =>
      _duplicateCheck.run(_duplicateInput, _performDuplicateCheck);

  Future<bool> _performDuplicateCheck() async {
    if (!_needsDuplicateCheck || _checkedApiInput == _duplicateInput) {
      return true;
    }
    if (!_validDuplicateInput) return false;
    final input = _duplicateInput;
    final version = ++_checkVersion;
    setState(() {
      _isCheckingDuplicate = true;
      _duplicateChecked = false;
      _error = null;
    });
    try {
      if (_apiMode) {
        final found = await widget.apiRepository!.checkDuplicate(
          _nameController.text.trim(),
          _normalizedPhone,
        );
        if (!mounted || version != _checkVersion) return false;
        _apiDuplicate = found?.id == widget.apiSalesRep?.id ? null : found;
      } else {
        final found = await context
            .read<SalesRepresentativeProvider>()
            .checkSalesRepDuplicate(_nameController.text.trim());
        if (!mounted || version != _checkVersion) return false;
        _duplicateRep = found?.id == widget.salesRep?.id ? null : found;
      }
      setState(() {
        _checkedApiInput = input;
        _duplicateChecked = true;
        _isCheckingDuplicate = false;
      });
      return true;
    } catch (_) {
      if (mounted && version == _checkVersion) {
        setState(() {
          _isCheckingDuplicate = false;
          _error = 'Не удалось проверить представителей. Повторите попытку.';
        });
      }
      return false;
    }
  }

  Future<void> _submitForm() async {
    if (_busy) return;
    if (_isEditMode && _changes.isEmpty) {
      if (_apiMode) {
        Navigator.of(context).pop(widget.apiSalesRep);
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
    if (_apiMode) {
      await _submitApi();
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (!await _checkDuplicate() || !mounted) return;
      final provider = context.read<SalesRepresentativeProvider>();
      final name = _nameController.text.trim();
      final phone = _normalizedPhone;
      final percent = formNumber(_commissionPercentController.text)!;
      final success = _isEditMode
          ? await provider.updateSalesRepresentative(
              widget.salesRep!.id,
              name,
              phone,
              percent,
              changes: UpdateSalesRepresentativeRequest(
                name: _changes['name'] as String?,
                phone: _changes['phone'] as String?,
                commissionPercent: _changes['commissionPercent'] as double?,
              ),
            )
          : await provider.addSalesRepresentative(name, phone, percent) != null;
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Не удалось сохранить изменения.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSalesRep() async {
    if (_apiMode && widget.apiSalesRep != null) {
      await _setApiActive(widget.apiSalesRep!);
      return;
    }
    if (widget.salesRep == null) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Удалить представителя?',
      content:
          'Вы действительно хотите удалить представителя «${widget.salesRep!.name}»?',
      confirmText: 'Удалить',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    final success = await context
        .read<SalesRepresentativeProvider>()
        .deleteSalesRepresentative(widget.salesRep!.id);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(success);
    } else {
      AppNotify.show(
        'Не удалось удалить торгового представителя',
        isError: true,
      );
    }
  }

  String get _apiInput =>
      '${_nameController.text.trim()}|${RussianPhoneInputFormatter.toApiPhone(_phoneController.text)}';
  Future<bool> _checkApiDuplicate() => _checkDuplicate();

  Future<void> _submitApi() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _checkApiDuplicate() || !mounted) return;
      final name = _nameController.text.trim();
      final phone = RussianPhoneInputFormatter.toApiPhone(
        _phoneController.text,
      );
      final percent = double.parse(
        _commissionPercentController.text.trim().replaceAll(',', '.'),
      );
      final saved = widget.apiSalesRep == null
          ? await widget.apiRepository!.create(
              name: name,
              phone: phone,
              commissionPercent: percent,
            )
          : await widget.apiRepository!.update(
              widget.apiSalesRep!.id,
              _changes,
            );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is ApiException && error.statusCode == 409) {
            _phoneError = 'Телефон уже используется другим представителем';
          } else {
            _error = 'Не удалось сохранить представителя. Повторите попытку.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setApiActive(ApiSalesRepresentative rep) async {
    if (_busy) return;
    final active = !rep.isActive;
    final confirmed = await confirmSalesRepresentativeActivity(
      context,
      name: rep.name,
      active: active,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.apiRepository!.update(rep.id, {
        'isActive': active,
      });
      if (mounted) Navigator.pop(context, saved);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось изменить активность представителя.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _duplicateCheck.dispose();
    _checkVersion++;
    _nameController.dispose();
    _phoneController.dispose();
    _commissionPercentController.dispose();

    _nameFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: BaseFormDialog(
        title: _isEditMode
            ? 'Редактирование представителя'
            : 'Добавление представителя',
        submitButtonText: _isEditMode
            ? (_changes.isEmpty ? 'ОК' : 'Сохранить')
            : 'Добавить',
        submitButtonWidth: 160,
        formKey: _formKey,
        onSubmit: _submitForm,
        isBusy: _busy,
        isLoading: _busy && !_isCheckingDuplicate,
        leadingAction: _isEditMode
            ? (_apiMode
                  ? AppSecondaryButton(
                      text: widget.apiSalesRep!.isActive
                          ? 'Деактивировать'
                          : 'Активировать',
                      destructive: widget.apiSalesRep!.isActive,
                      onPressed: _busy ? null : _deleteSalesRep,
                    )
                  : AppIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Удалить представителя',
                      destructive: true,
                      onPressed: _busy ? null : _deleteSalesRep,
                    ))
            : null,
        children: [
          DuplicateCheckStatusWidget(
            idleText: !_needsDuplicateCheck
                ? 'Поля проверки не изменены'
                : _validDuplicateInput
                ? 'Ожидание завершения ввода…'
                : _apiMode
                ? 'Для проверки заполните имя и телефон'
                : 'Для проверки заполните имя',
            isChecking: _isCheckingDuplicate,
            isChecked: _duplicateChecked,
            hasDuplicate: _apiMode
                ? _apiDuplicate != null
                : _duplicateRep != null,
            expandedChild: _apiDuplicate == null
                ? null
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!widget.directoryMode || !_apiDuplicate!.isActive)
                        AppPrimaryButton(
                          text: _apiDuplicate!.isActive
                              ? 'Выбрать представителя'
                              : widget.directoryMode
                              ? 'Активировать'
                              : 'Активировать и выбрать',
                          onPressed: _busy
                              ? null
                              : () {
                                  if (_apiDuplicate!.isActive) {
                                    Navigator.pop(context, _apiDuplicate);
                                  } else {
                                    _setApiActive(_apiDuplicate!);
                                  }
                                },
                        ),
                      AppSecondaryButton(
                        text: 'Открыть представителя',
                        onPressed: _busy || widget.onOpenSalesRep == null
                            ? null
                            : () => widget.onOpenSalesRep!(_apiDuplicate!),
                      ),
                    ],
                  ),
            warningText: _apiMode
                ? (_apiDuplicate == null
                      ? ''
                      : 'Найден похожий представитель: ${_apiDuplicate!.name} — ${_apiDuplicate!.isActive ? 'Активен' : 'Неактивен'}')
                : _duplicateRep != null
                ? 'Такой торговый представитель уже существует'
                : '',
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            enabled: !_busy,
            maxLength: _apiMode ? 120 : null,
            focusNode: _nameFocusNode,
            decoration: const InputDecoration(
              labelText: 'ФИО представителя *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Введите ФИО';
              if (value.trim().length > 120) return 'Не более 120 символов';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            inputFormatters: _apiMode
                ? const [RussianPhoneInputFormatter()]
                : null,
            forceErrorText: _phoneError,
            onFieldSubmitted: _apiMode ? (_) => _checkApiDuplicate() : null,
            validator: _apiMode
                ? (value) => RussianPhoneInputFormatter.isComplete(value ?? '')
                      ? null
                      : 'Введите 10 цифр номера после +7'
                : null,
            decoration: const InputDecoration(
              labelText: 'Телефон представителя',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _commissionPercentController,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Вознаграждение',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payments_outlined),
              suffixText: '%',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Укажите процент';
              }

              final normalized = value.trim().replaceAll(',', '.');
              final percent = double.tryParse(normalized);

              if (percent == null) {
                return 'Введите число';
              }

              if (!percent.isFinite || percent < 0 || percent > 100) {
                return 'Процент должен быть от 0 до 100';
              }

              return null;
            },
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
}

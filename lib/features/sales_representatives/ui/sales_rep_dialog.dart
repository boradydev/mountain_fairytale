import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/shared/widgets/russian_phone_input_formatter.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_model.dart';
import 'package:mountain_fairytale/features/sales_representatives/ui/sales_representative_provider.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/confirm_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';
import 'package:provider/provider.dart';

class SalesRepDialog extends StatefulWidget {
  final SalesRepresentative? salesRep;
  final ApiSalesRepresentative? apiSalesRep;
  final SalesRepresentativeApiRepository? apiRepository;
  final ValueChanged<ApiSalesRepresentative>? onOpenSalesRep;

  const SalesRepDialog({
    super.key,
    this.salesRep,
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

    _nameFocusNode.addListener(_onFocusChange);
    if (_apiMode) {
      for (final controller in [_nameController, _phoneController]) {
        controller.addListener(() {
          _checkVersion++;
          setState(() {
            _apiDuplicate = null;
            _checkedApiInput = null;
            _duplicateChecked = false;
            _isCheckingDuplicate = false;
            _error = null;
          });
        });
      }
      _phoneController.addListener(() => setState(() => _phoneError = null));
    }
  }

  void _onFocusChange() {
    if (!_nameFocusNode.hasFocus) {
      _checkDuplicate();
    }
  }

  Future<void> _checkDuplicate() async {
    if (_apiMode) {
      await _checkApiDuplicate();
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    if (_isEditMode &&
        widget.salesRep!.name.trim().toLowerCase() == name.toLowerCase()) {
      setState(() {
        _isCheckingDuplicate = false;
        _duplicateChecked = true;
        _duplicateRep = null;
      });
      return;
    }

    setState(() {
      _isCheckingDuplicate = true;
      _duplicateChecked = false;
      _duplicateRep = null;
    });

    final duplicate = await context
        .read<SalesRepresentativeProvider>()
        .checkSalesRepDuplicate(name);

    if (!mounted) return;

    setState(() {
      _isCheckingDuplicate = false;
      _duplicateChecked = true;
      _duplicateRep = duplicate;
    });
  }

  Future<void> _submitForm() async {
    if (_apiMode) {
      await _submitApi();
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SalesRepresentativeProvider>();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final commissionPercent = double.parse(
      _commissionPercentController.text.trim().replaceAll(',', '.'),
    );
    final bool success;

    if (_isEditMode) {
      success = await provider.updateSalesRepresentative(
        widget.salesRep!.id,
        name,
        phone,
        commissionPercent,
      );
    } else {
      final created = await provider.addSalesRepresentative(
        name,
        phone,
        commissionPercent,
      );
      success = created != null;
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(success); // Возвращаем признак успеха
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить изменения')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось удалить торгового представителя'),
        ),
      );
    }
  }

  String get _apiInput =>
      '${_nameController.text.trim()}|${RussianPhoneInputFormatter.toApiPhone(_phoneController.text)}';
  Future<bool> _checkApiDuplicate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty ||
        name.length > 120 ||
        !RussianPhoneInputFormatter.isComplete(_phoneController.text)) {
      return false;
    }
    if (_checkedApiInput == _apiInput) return true;
    final version = ++_checkVersion;
    final input = _apiInput;
    setState(() {
      _isCheckingDuplicate = true;
      _duplicateChecked = false;
      _error = null;
    });
    try {
      final found = await widget.apiRepository!.checkDuplicate(
        name,
        RussianPhoneInputFormatter.toApiPhone(_phoneController.text),
      );
      if (!mounted || version != _checkVersion) return false;
      setState(() {
        _apiDuplicate = found?.id == widget.apiSalesRep?.id ? null : found;
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
          : await widget.apiRepository!.update(widget.apiSalesRep!.id, {
              'name': name,
              'phone': phone,
              'commissionPercent': percent,
            });
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
    final confirmed = await ConfirmDialog.show(
      context,
      title: active
          ? 'Активировать представителя?'
          : 'Деактивировать представителя?',
      content: '«${rep.name}». Запись и история сохранятся.',
      confirmText: active ? 'Активировать' : 'Деактивировать',
      destructive: !active,
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
        submitButtonText: _isEditMode ? 'Сохранить' : 'Добавить',
        formKey: _formKey,
        onSubmit: _submitForm,
        isBusy: _busy,
        leadingAction: _isEditMode
            ? AppIconButton(
                icon: _apiMode
                    ? (widget.apiSalesRep!.isActive
                          ? Icons.archive_outlined
                          : Icons.restore)
                    : Icons.delete_outline,
                tooltip: _apiMode
                    ? (widget.apiSalesRep!.isActive
                          ? 'Деактивировать представителя'
                          : 'Активировать представителя')
                    : 'Удалить представителя',
                destructive: !_apiMode || widget.apiSalesRep!.isActive,
                onPressed: _busy ? null : _deleteSalesRep,
              )
            : null,
        children: [
          if (_busy) const LinearProgressIndicator(),
          DuplicateCheckStatusWidget(
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
                      AppPrimaryButton(
                        text: _apiDuplicate!.isActive
                            ? 'Выбрать представителя'
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

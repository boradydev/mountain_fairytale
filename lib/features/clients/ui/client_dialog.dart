import 'package:mountain_fairytale/shared/widgets/geo_attribution.dart';
import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/features/clients/data/location_repository.dart';
import 'package:mountain_fairytale/features/clients/ui/client_location_dialog.dart';
import 'package:mountain_fairytale/core/state/form_editing.dart';
import 'package:flutter/services.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/order_points_provider.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/route_constructor_provider.dart';
import 'package:mountain_fairytale/features/payment_methods/data/payment_method_model.dart';
import 'package:mountain_fairytale/features/payment_methods/ui/payment_method_dialog.dart';
import 'package:mountain_fairytale/features/sales_representatives/data/sales_representative_api_repo.dart';
import 'package:mountain_fairytale/features/sales_representatives/ui/sales_rep_dialog.dart';
import 'package:mountain_fairytale/shared/widgets/russian_phone_input_formatter.dart';
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

Future<Client?> showClientDialog(
  BuildContext context, {
  Client? client,
  OrderPointsProvider? orderProvider,
}) async {
  Client? openAfter;
  final result = await showDialog<Client>(
    context: context,
    builder: (dialogContext) => ClientDialog(
      client: client,
      orderProvider: orderProvider,
      onOpenClient: (existing) {
        openAfter = existing;
        Navigator.pop(dialogContext);
      },
    ),
  );
  if (openAfter != null && context.mounted) {
    return showClientDialog(
      context,
      client: openAfter,
      orderProvider: orderProvider,
    );
  }
  return result;
}

class ClientDialog extends StatefulWidget {
  final Client? client;
  final OrderPointsProvider? orderProvider;
  final ValueChanged<Client>? onOpenClient;
  const ClientDialog({
    super.key,
    this.client,
    this.orderProvider,
    this.onOpenClient,
  });
  bool get isEditMode => client != null;
  @override
  State<ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<ClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _locationFieldKey = GlobalKey<FormFieldState<bool>>();
  late final TextEditingController _district,
      _locality,
      _street,
      _house,
      _details;
  DeliveryAddress? _deliveryAddress;
  bool _locating = false;
  String? _locationError;
  Map<String, String> get _addressParts => {
    'district': _district.text.trim(),
    'locality': _locality.text.trim(),
    'street': _street.text.trim(),
    'house': _house.text.trim(),
  };
  void _addressChanged() {
    _deliveryAddress = null;
    _locationError = null;
    _locationFieldKey.currentState?.reset();
    _address.text = [
      'Ставропольский край',
      ..._addressParts.values.where((v) => v.isNotEmpty),
    ].join(', ');
    if (mounted) setState(() {});
  }

  Future<void> _verifyAddress({bool manual = false}) async {
    if (_locating || _busy) return;
    if (_addressParts.entries.any(
      (e) => e.key != 'district' && e.value.isEmpty,
    )) {
      _formKey.currentState?.validate();
      return;
    }
    final snapshot = Map<String, String>.of(_addressParts);
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final repository = context.read<LocationRepository>();
      final candidates = manual || _deliveryAddress != null
          ? <LocationCandidate>[]
          : await repository.search(snapshot);
      if (!mounted ||
          snapshot.entries.any((e) => _addressParts[e.key] != e.value)) {
        return;
      }
      final selected = await showClientLocationDialog(
        context,
        repository: repository,
        address: _address.text,
        candidates: candidates,
        existing: _deliveryAddress,
      );
      if (!mounted ||
          selected == null ||
          snapshot.entries.any((e) => _addressParts[e.key] != e.value)) {
        return;
      }
      setState(() {
        _deliveryAddress = DeliveryAddress(
          district: snapshot['district']!,
          locality: snapshot['locality']!,
          street: snapshot['street']!,
          house: snapshot['house']!,
          latitude: selected.latitude,
          longitude: selected.longitude,
          source: selected.manual ? 'manual' : 'geoapify',
          deliveryDetails: _details.text.trim(),
        );
      });
      _locationFieldKey.currentState?.didChange(true);
      _locationFieldKey.currentState?.validate();
    } catch (error) {
      if (mounted) {
        setState(
          () => _locationError = error is ApiException
              ? error.message
              : 'Не удалось проверить адрес. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _threshold;
  late final TextEditingController _cooldown;
  DateTime? _cooldownDate;
  final _focusNodes = List.generate(3, (_) => FocusNode());
  bool _busy = false;
  bool _checking = false;
  bool _loadingSalesReps = true;
  bool _loadingPayments = true;
  int _salesRepLoadVersion = 0;
  int _paymentLoadVersion = 0;
  bool _includeInactiveSalesReps = false;
  bool _includeInactivePayments = false;
  bool _editingDirectory = false;
  int _directoryVersion = 0;
  String? _error;
  String? _salesRepLoadError;
  String? _paymentLoadError;
  String? get _directoryError {
    final errors = [_salesRepLoadError, _paymentLoadError].whereType<String>();
    return errors.isEmpty ? null : errors.join('\n');
  }

  String? _phoneError;
  String? _checkedInput;
  int _checkVersion = 0;
  Client? _duplicate;
  String? _salesRepId;
  String? _paymentMethodId;
  List<ClientDirectoryEntry> _salesReps = [];
  List<ClientDirectoryEntry> _paymentMethods = [];
  String get _input => [
    _name.text.trim(),
    RussianPhoneInputFormatter.toApiPhone(_phone.text),
    _address.text.trim(),
  ].join('\n');

  late final Map<String, Object?> _originalValues;
  late final String _originalDuplicateInput;
  late final DuplicateCheckCoordinator _duplicateCheck;
  Map<String, Object?> get _values => {
    'name': _name.text.trim(),
    'phone': RussianPhoneInputFormatter.toApiPhone(_phone.text),
    'address': _address.text.trim(),
    'deliveryAddress': _deliveryAddress,
    'sleepingThresholdDays':
        int.tryParse(_threshold.text.trim()) ?? _threshold.text.trim(),
    'cooldownUntil': _cooldownDate,
    'salesRepresentativeId': _salesRepId,
    'defaultPaymentMethodId': _paymentMethodId,
  };
  Map<String, Object?> get _changes =>
      changedFormFields(_originalValues, _values);
  bool get _needsDuplicateCheck =>
      !widget.isEditMode || _input != _originalDuplicateInput;
  bool get _validDuplicateInput =>
      _name.text.trim().isNotEmpty &&
      _name.text.trim().length <= 120 &&
      RussianPhoneInputFormatter.isComplete(_phone.text) &&
      _address.text.trim().isNotEmpty &&
      _address.text.trim().length <= 500;
  void _refreshForm() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    _name = TextEditingController(text: client?.name ?? '');
    _phone = TextEditingController(
      text: RussianPhoneInputFormatter.format(client?.phone ?? ''),
    );
    _address = TextEditingController(text: client?.address ?? '');
    _deliveryAddress = client?.deliveryAddress;
    _district = TextEditingController(text: _deliveryAddress?.district ?? '');
    _locality = TextEditingController(text: _deliveryAddress?.locality ?? '');
    _street = TextEditingController(text: _deliveryAddress?.street ?? '');
    _house = TextEditingController(text: _deliveryAddress?.house ?? '');
    _details = TextEditingController(
      text: _deliveryAddress?.deliveryDetails ?? '',
    );
    for (final c in [_district, _locality, _street, _house]) {
      c.addListener(_addressChanged);
    }
    _details.addListener(() {
      final a = _deliveryAddress;
      if (a != null) {
        _deliveryAddress = DeliveryAddress(
          district: a.district,
          locality: a.locality,
          street: a.street,
          house: a.house,
          latitude: a.latitude,
          longitude: a.longitude,
          source: a.source,
          deliveryDetails: _details.text.trim(),
        );
      }
      _refreshForm();
    });
    _threshold = TextEditingController(
      text: client?.sleepingThresholdDays.toString() ?? '7',
    );
    final cooldown = client?.cooldownUntil;
    _cooldownDate = cooldown == null
        ? null
        : DateTime(cooldown.year, cooldown.month, cooldown.day);
    _cooldown = TextEditingController(text: _cooldownLabel(_cooldownDate));
    _salesRepId = client?.salesRepresentativeId;
    _paymentMethodId = client?.defaultPaymentMethodId;
    _salesReps = _withCurrent([], _salesRepId, client?.salesRepresentativeName);
    _paymentMethods = _withCurrent(
      [],
      _paymentMethodId,
      client?.defaultPaymentMethodName,
    );
    _originalValues = Map.of(_values);
    _originalDuplicateInput = _input;
    _duplicateCheck = DuplicateCheckCoordinator(_input);
    for (final controller in [_name, _phone, _address]) {
      controller.addListener(() {
        final changed = _duplicateCheck.inputChanged(
          _input,
          canCheck: _needsDuplicateCheck && _validDuplicateInput,
          check: _checkDuplicate,
        );
        setState(() {
          if (changed) {
            _checkVersion++;
            _duplicate = null;
            _checkedInput = null;
            _checking = false;
          }
          _error = null;
        });
      });
    }
    _threshold.addListener(_refreshForm);
    _cooldown.addListener(_refreshForm);
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
        name ?? 'Недоступная запись',
        isActive: false,
      ),
    ];
  }

  Future<void> _loadDirectories() async {
    await Future.wait([
      _loadDirectory(salesRep: true),
      _loadDirectory(salesRep: false),
    ]);
  }

  Future<void> _loadDirectory({required bool salesRep}) async {
    if (!mounted) return;
    final version = salesRep ? ++_salesRepLoadVersion : ++_paymentLoadVersion;
    bool isCurrent() =>
        mounted &&
        version == (salesRep ? _salesRepLoadVersion : _paymentLoadVersion);
    setState(() {
      if (salesRep) {
        _loadingSalesReps = true;
        _salesRepLoadError = null;
      } else {
        _loadingPayments = true;
        _paymentLoadError = null;
      }
    });
    try {
      final provider = context.read<ClientsProvider>();
      final rows = salesRep
          ? await provider.getSalesRepresentatives(
              includeDeactivated: _includeInactiveSalesReps,
            )
          : await provider.getPaymentMethods(
              includeDeactivated: _includeInactivePayments,
            );
      if (!isCurrent()) return;
      setState(() {
        if (salesRep) {
          _salesReps = _withCurrent(
            rows,
            _salesRepId,
            _selectedEntry(_salesReps, _salesRepId)?.name ??
                widget.client?.salesRepresentativeName,
          );
        } else {
          _paymentMethods = _withCurrent(
            rows,
            _paymentMethodId,
            _selectedEntry(_paymentMethods, _paymentMethodId)?.name ??
                widget.client?.defaultPaymentMethodName,
          );
        }
      });
    } catch (_) {
      if (isCurrent()) {
        setState(() {
          if (salesRep) {
            _salesRepLoadError =
                'Не удалось загрузить представителей. Повторите попытку.';
          } else {
            _paymentLoadError =
                'Не удалось загрузить способы оплаты. Повторите попытку.';
          }
        });
      }
    } finally {
      if (isCurrent()) {
        setState(() {
          if (salesRep) {
            _loadingSalesReps = false;
          } else {
            _loadingPayments = false;
          }
        });
      }
    }
  }

  Future<bool> _checkDuplicate() =>
      _duplicateCheck.run(_input, _performDuplicateCheck);

  Future<bool> _performDuplicateCheck() async {
    if (!_needsDuplicateCheck) return true;
    if (_name.text.trim().isEmpty ||
        !RussianPhoneInputFormatter.isComplete(_phone.text) ||
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
        RussianPhoneInputFormatter.toApiPhone(_phone.text),
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
    return '${two(value.day)}.${two(value.month)}.${value.year}';
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
    setState(() {
      _cooldownDate = DateTime(date.year, date.month, date.day);
      _cooldown.text = _cooldownLabel(_cooldownDate);
    });
  }

  Future<void> _save() async {
    if (_busy || _editingDirectory || _locating) return;
    if (widget.isEditMode && _changes.isEmpty) {
      Navigator.of(context).pop(widget.client);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_deliveryAddress == null) {
      setState(() => _locationError = 'Проверьте и подтвердите местоположение');
      return;
    }
    final provider = context.read<ClientsProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _checkDuplicate() || !mounted) return;
      if (!widget.isEditMode) {
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
              changes: UpdateClientRequest.fromChanges(_changes),
              name: _name.text.trim(),
              phone: RussianPhoneInputFormatter.toApiPhone(_phone.text),
              address: _address.text.trim(),
              deliveryAddress: _deliveryAddress,
              thresholdDays: int.parse(_threshold.text.trim()),
              salesRepId: _salesRepId,
              paymentMethodId: _paymentMethodId,
              cooldownUntil: cooldown,
            )
          : await provider.addClient(
              name: _name.text.trim(),
              phone: RussianPhoneInputFormatter.toApiPhone(_phone.text),
              address: _address.text.trim(),
              deliveryAddress: _deliveryAddress,
              thresholdDays: int.parse(_threshold.text.trim()),
              salesRepId: _salesRepId,
              paymentMethodId: _paymentMethodId,
              cooldownUntil: cooldown,
            );
      if (!mounted) return;
      if (success) {
        Navigator.pop(context, provider.lastSavedClient);
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
      Navigator.pop(context, provider.lastSavedClient);
    } else {
      setState(() {
        _busy = false;
        _error = provider.errorMessage;
      });
    }
  }

  @override
  void dispose() {
    _duplicateCheck.dispose();
    _checkVersion++;
    _directoryVersion++;
    for (final controller in [
      _name,
      _phone,
      _address,
      _threshold,
      _cooldown,
      _district,
      _locality,
      _street,
      _house,
      _details,
    ]) {
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
    List<TextInputFormatter>? inputFormatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      focusNode: focus,
      enabled: !_busy && !_editingDirectory,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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

  ClientDirectoryEntry? _selectedEntry(
    List<ClientDirectoryEntry> rows,
    String? id,
  ) {
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  Future<void> _showPaymentEditor({String? id}) async {
    if (_busy || _editingDirectory || _locating) return;
    setState(() => _editingDirectory = true);
    try {
      final provider =
          widget.orderProvider ?? context.read<RouteConstructorProvider>();
      PaymentMethod? current;
      if (id != null) {
        await provider.loadSelectedPaymentMethod(id);
        current = provider.paymentMethodsById[id];
      }
      if (!mounted) return;
      PaymentMethod? openAfter;
      final saved = await showDialog<PaymentMethod>(
        context: context,
        builder: (dialogContext) => PaymentMethodDialog(
          provider: provider,
          paymentMethod: current,
          onOpenPaymentMethod: (existing) {
            openAfter = existing;
            Navigator.pop(dialogContext);
          },
        ),
      );
      if (!mounted) return;
      final edited = saved ?? provider.paymentMethodsById[id];
      if (edited != null) {
        setState(() {
          if (saved != null) _paymentMethodId = saved.id;
          _paymentMethods = [
            ..._paymentMethods.where((row) => row.id != edited.id),
            ClientDirectoryEntry(
              edited.id,
              edited.name,
              isActive: edited.isActive,
            ),
          ];
        });
      }
      await _loadDirectory(salesRep: false);
      if (!mounted) return;
      setState(() => _editingDirectory = false);
      if (openAfter != null) await _showPaymentEditor(id: openAfter!.id);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось открыть способ оплаты. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _editingDirectory = false);
    }
  }

  Future<void> _showSalesRepEditor({String? id}) async {
    if (_busy || _editingDirectory || _locating) return;
    setState(() => _editingDirectory = true);
    try {
      final repository = context.read<SalesRepresentativeApiRepository>();
      final current = id == null ? null : await repository.get(id);
      if (!mounted) return;
      ApiSalesRepresentative? openAfter;
      final saved = await showDialog<ApiSalesRepresentative>(
        context: context,
        builder: (dialogContext) => SalesRepDialog(
          apiRepository: repository,
          apiSalesRep: current,
          onOpenSalesRep: (existing) {
            openAfter = existing;
            Navigator.pop(dialogContext);
          },
        ),
      );
      if (!mounted) return;
      if (saved != null) {
        setState(() {
          _salesRepId = saved.isActive ? saved.id : null;
          _salesReps = [
            ..._salesReps.where((row) => row.id != saved.id),
            ClientDirectoryEntry(
              saved.id,
              saved.name,
              isActive: saved.isActive,
            ),
          ];
        });
      }
      await _loadDirectory(salesRep: true);
      if (!mounted) return;
      setState(() => _editingDirectory = false);
      if (openAfter != null) await _showSalesRepEditor(id: openAfter!.id);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось открыть представителя. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _editingDirectory = false);
    }
  }

  Future<void> _activateDirectory(
    ClientDirectoryEntry entry,
    bool salesRep,
  ) async {
    if (_busy || _editingDirectory || _locating) return;
    setState(() => _editingDirectory = true);
    try {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Активировать и выбрать?',
        content: '«${entry.name}» снова станет доступен.',
        confirmText: 'Активировать и выбрать',
      );
      if (!confirmed || !mounted) return;
      if (salesRep) {
        final active = await context
            .read<SalesRepresentativeApiRepository>()
            .update(entry.id, {'isActive': true});
        if (mounted) {
          setState(() {
            _salesRepId = active.id;
            _salesReps = [
              ..._salesReps.where((row) => row.id != active.id),
              ClientDirectoryEntry(active.id, active.name),
            ];
          });
        }
      } else {
        final provider =
            widget.orderProvider ?? context.read<RouteConstructorProvider>();
        await provider.loadSelectedPaymentMethod(entry.id);
        final active = await provider.activatePaymentMethod(
          provider.paymentMethodsById[entry.id]!,
        );
        if (active == null) throw StateError('Activation failed');
        if (mounted) {
          setState(() {
            _paymentMethodId = active.id;
            _paymentMethods = [
              ..._paymentMethods.where((row) => row.id != active.id),
              ClientDirectoryEntry(active.id, active.name),
            ];
          });
        }
      }
      if (mounted) await _loadDirectory(salesRep: salesRep);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось активировать запись. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _editingDirectory = false;
          _directoryVersion++;
        });
      }
    }
  }

  Widget _directory(
    String label,
    List<ClientDirectoryEntry> rows,
    String? id,
    ValueChanged<String?> onChanged,
    IconData icon, {
    required bool isLoading,
    required bool hasLoadError,
    required bool includeInactive,
    required ValueChanged<bool> onIncludeInactiveChanged,
    required VoidCallback onAdd,
    required VoidCallback? onEdit,
  }) {
    final selected = _selectedEntry(rows, id);
    final visible = rows
        .where((row) => includeInactive || row.isActive)
        .toList();
    final selectedVisible = id == null || visible.any((row) => row.id == id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppDropdown<String>(
        isLoading: isLoading,
        key: ValueKey(
          '$label-$id-$includeInactive-${selected?.name}-${selected?.isActive}-$_directoryVersion',
        ),
        label: label,
        items: ['', ...visible.map((row) => row.id)],
        value: selectedVisible ? id ?? '' : null,
        hint: selected == null ? 'Не выбран' : '${selected.name} — Неактивен',
        enabled: !_busy && !_editingDirectory && !isLoading && !hasLoadError,
        prefixIcon: icon,
        showInactiveToggle: true,
        includeInactive: includeInactive,
        showEdit: true,
        showAdd: true,
        editBeforeAdd: true,
        onIncludeInactiveChanged: onIncludeInactiveChanged,
        onAdd: onAdd,
        onEdit: onEdit,
        itemLabelBuilder: (value) => value.isEmpty
            ? 'Не выбран'
            : '${rows.firstWhere((row) => row.id == value).name}${rows.firstWhere((row) => row.id == value).isActive ? '' : ' — Неактивен'}',
        onChanged: (value) {
          // Existing inactive links are preserved; newly assigning an inactive row requires activation first.
          if (value != null &&
              value.isNotEmpty &&
              !_selectedEntry(rows, value)!.isActive &&
              value != id) {
            if (icon == Icons.badge_outlined) {
              _activateDirectory(_selectedEntry(rows, value)!, true);
            } else {
              _activateDirectory(_selectedEntry(rows, value)!, false);
            }
            return;
          }
          onChanged(value == null || value.isEmpty ? null : value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_editingDirectory,
    child: BaseFormDialog(
      title: widget.isEditMode
          ? 'Редактирование клиента'
          : 'Добавление клиента',
      submitButtonText: widget.isEditMode
          ? (_changes.isEmpty ? 'ОК' : 'Сохранить')
          : 'Добавить',
      submitButtonWidth: 160,
      formKey: _formKey,
      onSubmit: _save,
      isBusy: _busy || _editingDirectory,
      leadingAction: widget.client == null
          ? null
          : AppSecondaryButton(
              text: widget.client!.isActive ? 'Деактивировать' : 'Активировать',
              destructive: widget.client!.isActive,
              onPressed: _busy
                  ? null
                  : () => _setActive(widget.client!, !widget.client!.isActive),
            ),
      children: [
        if (widget.client != null && !widget.client!.isActive)
          const Text('Клиент деактивирован'),
        DuplicateCheckStatusWidget(
          idleText: !_needsDuplicateCheck
              ? 'Поля проверки не изменены'
              : _validDuplicateInput
              ? 'Ожидание завершения ввода…'
              : 'Для проверки заполните имя, телефон и адрес',
          isChecking: _checking,
          isChecked: _checkedInput != null,
          hasDuplicate: _duplicate != null,
          warningText: _duplicate == null
              ? ''
              : 'Найден похожий клиент: ${_duplicate!.name} — ${_duplicate!.isActive ? 'Активен' : 'Неактивен'}\n${_duplicate!.phone}\n${_duplicate!.address}',
          expandedChild: _duplicate == null
              ? null
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.orderProvider != null)
                      AppPrimaryButton(
                        text: _duplicate!.isActive
                            ? 'Добавить клиента'
                            : 'Активировать и добавить',
                        onPressed: _busy
                            ? null
                            : () {
                                if (_duplicate!.isActive) {
                                  Navigator.pop(context, _duplicate);
                                } else {
                                  _setActive(_duplicate!, true);
                                }
                              },
                      ),
                    AppSecondaryButton(
                      text: 'Открыть клиента',
                      onPressed: _busy || widget.onOpenClient == null
                          ? null
                          : () => widget.onOpenClient!(_duplicate!),
                    ),
                  ],
                ),
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
          _district,
          'Район / муниципальный или городской округ',
          Icons.location_city,
          maxLength: 150,
          validator: (_) => null,
          hint: 'Необязательно; укажите для уточнения адреса',
        ),
        _field(
          _locality,
          'Населённый пункт (с типом) *',
          Icons.location_city,
          maxLength: 150,
        ),
        _field(
          _street,
          'Улица (с типом) *',
          Icons.signpost_outlined,
          maxLength: 150,
        ),
        _field(_house, 'Дом *', Icons.home_outlined, maxLength: 40),
        _field(
          _details,
          'Детали доставки',
          Icons.notes,
          maxLength: 500,
          validator: (_) => null,
        ),
        FormField<bool>(
          key: _locationFieldKey,
          validator: (_) => _deliveryAddress == null
              ? 'Подтвердите местоположение клиента'
              : null,
          builder: (field) => InputDecorator(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              errorText: _locationError ?? field.errorText,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _deliveryAddress == null
                      ? 'Местоположение не подтверждено'
                      : 'Местоположение подтверждено',
                ),
                const SizedBox(height: 8),
                AppSecondaryButton(
                  text: _locating
                      ? 'Проверка…'
                      : _deliveryAddress == null
                      ? 'Проверить адрес'
                      : 'Изменить местоположение',
                  onPressed: _busy || _locating ? null : () => _verifyAddress(),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: _busy || _locating
              ? null
              : () => _verifyAddress(manual: true),
          child: const Text('Указать место вручную'),
        ),
        const GeoAttribution(),
        const SizedBox(height: 16),
        _field(
          _phone,
          'Номер телефона *',
          Icons.phone_outlined,
          maxLength: 32,
          focus: _focusNodes[1],
          hint: '+7 999 123 45 67',
          inputFormatters: const [RussianPhoneInputFormatter()],
          validator: (value) =>
              RussianPhoneInputFormatter.isComplete(value ?? '')
              ? null
              : 'Введите 10 цифр номера после +7',
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
            enabled: !_busy && !_editingDirectory,
            onTap: _pickCooldown,
            decoration: InputDecoration(
              labelText: 'Отсрочка до',
              hintText: 'Выберите дату',
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
          isLoading: _loadingSalesReps,
          hasLoadError: _salesRepLoadError != null,
          includeInactive: _includeInactiveSalesReps,
          onIncludeInactiveChanged: (value) {
            setState(() => _includeInactiveSalesReps = value);
            _loadDirectory(salesRep: true);
          },
          onAdd: () => _showSalesRepEditor(),
          onEdit: _salesRepId == null
              ? null
              : () => _showSalesRepEditor(id: _salesRepId),
        ),
        _directory(
          'Способ оплаты по умолчанию',
          _paymentMethods,
          _paymentMethodId,
          (id) => setState(() => _paymentMethodId = id),
          Icons.payments_outlined,
          isLoading: _loadingPayments,
          hasLoadError: _paymentLoadError != null,
          includeInactive: _includeInactivePayments,
          onIncludeInactiveChanged: (value) {
            setState(() => _includeInactivePayments = value);
            _loadDirectory(salesRep: false);
          },
          onAdd: () => _showPaymentEditor(),
          onEdit: _paymentMethodId == null
              ? null
              : () => _showPaymentEditor(id: _paymentMethodId),
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

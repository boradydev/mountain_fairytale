import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/screens/delivery_days_screen/sales_rep_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/confirm_delete_dialog.dart';
import 'package:mountain_fairytale/presentation/widgets/duplicate_check_status_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/icon_button_widget.dart';
import 'package:provider/provider.dart';

class ClientDialog extends StatefulWidget {
  final Client? client;

  const ClientDialog({
    super.key,
    this.client,
  });

  bool get isEditMode => client != null;

  @override
  State<ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<ClientDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _thresholdController;

  final _nameFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();

  bool _isCheckingDuplicate = false;
  bool _duplicateChecked = false;
  Client? _duplicateClient;

  bool get _isEditMode => widget.client != null;
  SalesRepresentative? _selectedSalesRep;

  @override
  void initState() {
    super.initState();

    // Подгружаем торговых представителей при открытии диалога
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientsProvider>().fetchSalesRepresentatives();
    });

    final client = widget.client;

    _nameController = TextEditingController(
      text: client?.name ?? '',
    );

    _phoneController = TextEditingController(
      text: client?.phone ?? '',
    );

    _addressController = TextEditingController(
      text: client?.address ?? '',
    );

    _thresholdController = TextEditingController(
      text: client?.sleepingThresholdDays.toString() ?? '7',
    );

    _nameFocusNode.addListener(_onFocusChange);
    _addressFocusNode.addListener(_onFocusChange);

    // Восстанавливаем сохраненного представителя в режиме редактирования
    if (client != null && client.salesRepresentativeId != null) {
      _selectedSalesRep = SalesRepresentative(
        id: client.salesRepresentativeId!,
        name: client.salesRepresentativeName ?? '',
        phone: '',
      );
    }
  }


  void _onFocusChange() {
    if (_nameFocusNode.hasFocus || _addressFocusNode.hasFocus) {
      return;
    }

    _checkDuplicate();
  }

  Future<void> _checkDuplicate() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || address.isEmpty) {
      return;
    }

    // В режиме редактирования, если имя и адрес
    // остались прежними — сам клиент не является дубликатом.
    final currentClient = widget.client;

    if (currentClient != null &&
        currentClient.name.trim().toLowerCase() == name.toLowerCase() &&
        currentClient.address.trim().toLowerCase() == address.toLowerCase()) {
      setState(() {
        _isCheckingDuplicate = false;
        _duplicateChecked = true;
        _duplicateClient = null;
      });
      return;
    }

    setState(() {
      _isCheckingDuplicate = true;
      _duplicateChecked = false;
      _duplicateClient = null;
    });

    final duplicate = await context
        .read<ClientsProvider>()
        .checkClientDuplicate(name, address);

    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingDuplicate = false;
      _duplicateChecked = true;
      _duplicateClient = duplicate;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<ClientsProvider>();

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final thresholdDays = int.parse(_thresholdController.text.trim());

    final bool success;

    if (_isEditMode) {
      success = await provider.updateClient(
        clientId: widget.client!.id,
        name: name,
        phone: phone,
        address: address,
        thresholdDays: thresholdDays,
        salesRepId: _selectedSalesRep?.id,
        // <-- Добавлено
        salesRepName: _selectedSalesRep?.name, // <-- Добавлено
      );
    } else {
      success = await provider.addClient(
        name: name,
        phone: phone,
        address: address,
        thresholdDays: thresholdDays,
        salesRepId: _selectedSalesRep?.id,
        // <-- Добавлено
        salesRepName: _selectedSalesRep?.name, // <-- Добавлено
      );
    }

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop();
      return;
    }

    _showError();
  }

  Future<void> _deleteClient() async {
    final client = widget.client;

    if (client == null) {
      return;
    }

    final confirmed = await ConfirmDeleteDialog.show(
      context,
      entityName: 'клиента «${client.name}»',
    );

    if (!confirmed || !mounted) {
      return;
    }

    final success = await context
        .read<ClientsProvider>()
        .deleteClient(client.id);

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop();
      return;
    }

    _showError();
  }

  void _showError() {
    final error = context.read<ClientsProvider>().errorMessage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.isEmpty
              ? 'Не удалось сохранить изменения'
              : 'Ошибка: $error',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _thresholdController.dispose();

    _nameFocusNode.dispose();
    _addressFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseFormDialog(
      title: _isEditMode
          ? 'Редактирование клиента'
          : 'Добавление нового клиента',

      submitButtonText: _isEditMode
          ? 'Сохранить'
          : 'Создать клиента',

      formKey: _formKey,
      onSubmit: _submitForm,

      leadingAction: _isEditMode
          ? AppIconButton(
        icon: Icons.delete_outline,
        tooltip: 'Удалить клиента',
        destructive: true,
        onPressed: _deleteClient,
      )
          : null,

      children: [
        DuplicateCheckStatusWidget(
          isChecking: _isCheckingDuplicate,
          isChecked: _duplicateChecked,
          hasDuplicate: _duplicateClient != null,
          warningText: _duplicateClient != null
              ? 'Найден похожий клиент: '
              '${_duplicateClient!.name}\n'
              '${_duplicateClient!.address}\n'
              '${_duplicateClient!.phone}'
              : '',
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          decoration: const InputDecoration(
            labelText: 'Название организации / ФИО *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите название';
            }

            return null;
          },
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _addressController,
          focusNode: _addressFocusNode,
          decoration: const InputDecoration(
            labelText: 'Адрес доставки *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите адрес';
            }

            return null;
          },
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Номер телефона *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_outlined),
            hintText: '+7 (XXX) XXX-XX-XX',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите телефон';
            }

            return null;
          },
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _thresholdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Порог засыпания (в днях) *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.hourglass_empty_rounded),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите количество дней';
            }

            final days = int.tryParse(value.trim());

            if (days == null || days <= 0) {
              return 'Введите корректное число дней';
            }

            return null;
          },
        ),

        const SizedBox(height: 16),

        // Блок Торговый представитель
        Row(
          children: [
            const Expanded(
              child: Text(
                'Торговый представитель',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => const SalesRepDialog(),
                );
              },
              icon: const Icon(Icons.add),
              tooltip: 'Добавить торгового представителя',
            ),
            IconButton(
              onPressed: _selectedSalesRep != null
                  ? () async {
                final result = await showDialog<dynamic>(
                  context: context,
                  builder: (_) => SalesRepDialog(salesRep: _selectedSalesRep),
                );
                // Если представитель был удален, сбрасываем значение локального выбора
                if (result == true && !mounted) return;
                final provider = context.read<ClientsProvider>();
                if (!provider.salesRepresentatives.contains(
                    _selectedSalesRep)) {
                  setState(() {
                    _selectedSalesRep = null;
                  });
                }
              }
                  : null,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Редактировать торгового представителя',
            ),
          ],
        ),

        Consumer<ClientsProvider>(
          builder: (context, provider, child) {
            // Находим реальный объект из списка по ID, чтобы у Dropdown совпадали ссылки
            SalesRepresentative? currentSelection;
            if (_selectedSalesRep != null) {
              try {
                currentSelection =
                    provider.salesRepresentatives.firstWhere((r) =>
                    r.id ==
                        _selectedSalesRep!.id);
              } catch (_) {
                _selectedSalesRep = null;
              }
            }

            return DropdownButtonFormField<SalesRepresentative>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              initialValue: currentSelection,
              // Используем сопоставленный объект
              hint: const Text('Выберите представителя'),
              items: provider.salesRepresentatives.map((rep) {
                return DropdownMenuItem<SalesRepresentative>(
                  value: rep,
                  child: Text(rep.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSalesRep = value;
                });
              },
            );
          },

        ),

        const SizedBox(height: 16),

      ],
    );
  }
}
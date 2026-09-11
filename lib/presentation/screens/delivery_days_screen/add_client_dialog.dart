import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/duplicate_check_status_widget.dart';
import 'package:provider/provider.dart';

class AddClientDialog extends StatefulWidget {
  const AddClientDialog({super.key});

  @override
  State<AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<AddClientDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _thresholdController = TextEditingController(text: '7');

  final _nameFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();

  bool _isCheckingDuplicate = false;
  bool _duplicateChecked = false;
  Client? _duplicateClient;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(_onFocusChange);
    _addressFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() async {
    if (!_nameFocusNode.hasFocus && !_addressFocusNode.hasFocus) {
      final name = _nameController.text.trim();
      final address = _addressController.text.trim();

      if (name.isNotEmpty && address.isNotEmpty) {
        setState(() {
          _isCheckingDuplicate = true;
        });

        final duplicate = await context.read<ClientsProvider>().checkClientDuplicate(name, address);

        setState(() {
          _isCheckingDuplicate = false;
          _duplicateChecked = true;
          _duplicateClient = duplicate; // Просто записываем объект (или null)
        });
      }
    }
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

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      context.read<ClientsProvider>().addClient(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        thresholdDays: int.parse(_thresholdController.text.trim()),
      );
      Navigator.of(context).pop(); // Закрываем диалог после успешного добавления
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseFormDialog(
      title: 'Добавление нового клиента',
      submitButtonText: 'Создать клиента',
      formKey: _formKey,
      onSubmit: _submitForm,
      children: [
        // Универсальный статус проверки дубликатов
        DuplicateCheckStatusWidget(
          isChecking: _isCheckingDuplicate,
          isChecked: _duplicateChecked,
          // Передаем true, если объект не null
          hasDuplicate: _duplicateClient != null,
          // Формируем строку на лету: если дубликат есть — берем его поля, если нет — пустую строку
          warningText: _duplicateClient != null
              ? 'Найден похожий клиент: '
              '${_duplicateClient!.name} '
              '\n${_duplicateClient!.address} '
              '\n${_duplicateClient!.phone}'
              : '',
        ),

        const SizedBox(height: 8), // Небольшой отступ после плашки статуса

        // Поле: Название организации
        TextFormField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          decoration: const InputDecoration(
            labelText: 'Название организации / ФИО *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) =>
          value == null || value
              .trim()
              .isEmpty ? 'Введите название' : null,
        ),
        const SizedBox(height: 16),

        // Поле: Адрес доставки
        TextFormField(
          controller: _addressController,
          focusNode: _addressFocusNode,
          decoration: const InputDecoration(
            labelText: 'Фактический адрес доставки *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          validator: (value) =>
          value == null || value
              .trim()
              .isEmpty ? 'Введите адрес' : null,
        ),
        const SizedBox(height: 16),

        // Поле: Номер телефона
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Номер телефона *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_outlined),
            hintText: '+7 (XXX) XXX-XX-XX',
          ),
          validator: (value) =>
          value == null || value
              .trim()
              .isEmpty ? 'Введите телефон' : null,
        ),
        const SizedBox(height: 16),

        // Поле: Порог засыпания
        TextFormField(
          controller: _thresholdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Порог засыпания (в днях) *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.hourglass_empty_rounded),
          ),
          validator: (value) {
            if (value == null || value
                .trim()
                .isEmpty) {
              return 'Введите количество дней';
            }
            if (int.tryParse(value.trim()) == null) {
              return 'Введите корректное число';
            }
            return null;
          },
        ),
      ],
    );
  }
}

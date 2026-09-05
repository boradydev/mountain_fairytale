import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
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

  Client? _duplicateClient;
  bool _isCheckingDuplicate = false;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(_onFocusChange);
    _addressFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() async {
    // Проверяем, ушел ли фокус с ОБОИХ полей, при этом оба поля должны быть заполнены
    if (!_nameFocusNode.hasFocus && !_addressFocusNode.hasFocus) {
      final name = _nameController.text.trim();
      final address = _addressController.text.trim();

      if (name.isNotEmpty && address.isNotEmpty) {
        setState(() {
          _isCheckingDuplicate = true;
        });

        final duplicate = await context.read<ClientsProvider>().checkClientDuplicate(name, address);

        setState(() {
          _duplicateClient = duplicate;
          _isCheckingDuplicate = false;
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
        name: _nameController.text,
        phone: _phoneController.text,
        address: _addressController.text,
        thresholdDays: int.parse(_thresholdController.text),
      );
      Navigator.of(context).pop(); // Закрываем диалог после успешного добавления
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500, // Фиксированная ширина для десктопа
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Добавление нового клиента',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 16),

                // --- БЛОК ИНФОРМАЦИИ О ДУБЛИКАТЕ ---
                if (_isCheckingDuplicate)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Проверка на дубликаты...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                if (_duplicateClient != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade600),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Внимание! Возможный дубликат',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Найден клиент: ID ${_duplicateClient!.id}\n'
                                    'Название: ${_duplicateClient!.name}\n'
                                    'Адрес: ${_duplicateClient!.address}\n'
                                    'Телефон: ${_duplicateClient!.phone}',
                                style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // ----------------------------------

                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Название организации / ФИО *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  focusNode: _addressFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Фактический адрес доставки *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Введите адрес' : null,
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
                  validator: (value) => value == null || value.trim().isEmpty ? 'Введите телефон' : null,
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
                    if (value == null || value.isEmpty) return 'Введите количество дней';
                    if (int.tryParse(value) == null) return 'Введите корректное число';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('Создать клиента'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

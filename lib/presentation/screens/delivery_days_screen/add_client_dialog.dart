import 'package:flutter/material.dart';
import 'package:mountain_fairytale/core/theme_extensions.dart';
import 'package:mountain_fairytale/infrastructure/repos/clients/models/client_model.dart';
import 'package:mountain_fairytale/presentation/providers/clients_provider.dart';
import 'package:mountain_fairytale/presentation/widgets/metric_row_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';
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
  bool _duplicateChecked = false;

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
          _duplicateChecked = true;
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

                // --- СТАТУС ПРОВЕРКИ НА ДУБЛИКАТЫ ---
                _DuplicateCheckStatus(
                  isChecking: _isCheckingDuplicate,
                  isChecked: _duplicateChecked,
                  duplicateClient: _duplicateClient,),

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
                    AppSecondaryButton(
                      onPressed: () => Navigator.of(context).pop(),
                      text: 'Отмена',
                    ),
                    const SizedBox(width: 8),
                    AppPrimaryButton(
                      onPressed: _submitForm,
                      text: 'Создать клиента',
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

class _DuplicateCheckStatus extends StatelessWidget {
  final bool isChecking;
  final bool isChecked;
  final Client? duplicateClient;

  const _DuplicateCheckStatus({
    required this.isChecking,
    required this.isChecked,
    required this.duplicateClient,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;
    final customColors = Theme.of(context).extension<AppColorsExtension>()!;
    final hasDuplicate = duplicateClient != null;

    final Color contentColor;
    final IconData icon;
    final String text;

    if (isChecking) {
      contentColor = colorScheme.onSurfaceVariant;
      icon = Icons.hourglass_empty_rounded;
      text = 'Проверка на дубликаты...';
    } else if (!isChecked) {
      contentColor = colorScheme.onSurfaceVariant;
      icon = Icons.help_outline_rounded    ;
      text = 'Введите данные для проверки...';
    } else if (hasDuplicate) {
      contentColor = customColors.warningColor;
      icon = Icons.info_outline;
      text = 'Найдены возможные дубликаты';
    } else {
      contentColor = customColors.successColor;
      icon = Icons.check_circle_outline;
      text = 'Дубликаты не найдены';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- СТАТУС ---
          Row(
            children: [
              if (isChecking)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: contentColor,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: contentColor,
                ),
              const SizedBox(width: 10),
              Text(
                text,
                style: TextStyle(
                  color: contentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // --- ИНФОРМАЦИЯ О ДУБЛИКАТЕ ---
          if (hasDuplicate) ...[
            const SizedBox(height: 12),
            Divider(
              color: colorScheme.outlineVariant.withAlpha(128),
              height: 1,
            ),
            const SizedBox(height: 6),
            MetricRow(
              label: 'ID клиента:',
              value: duplicateClient!.id.toString(),
              labelWidth: 100,
            ),
            MetricRow(
              label: 'Название:',
              value: duplicateClient!.name,
              labelWidth: 100,
            ),
            MetricRow(
              label: 'Адрес:',
              value: duplicateClient!.address,
              labelWidth: 100,
            ),
            MetricRow(
              label: 'Телефон:',
              value: duplicateClient!.phone,
              labelWidth: 100,
            ),
          ],
        ],
      ),
    );
  }
}


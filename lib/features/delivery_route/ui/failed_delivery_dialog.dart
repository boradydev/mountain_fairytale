import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';

class FailedDeliveryDialog extends StatefulWidget {
  final String initialReason;
  const FailedDeliveryDialog({super.key, this.initialReason = ''});
  @override
  State<FailedDeliveryDialog> createState() => _FailedDeliveryDialogState();
}

class _FailedDeliveryDialogState extends State<FailedDeliveryDialog> {
  final _form = GlobalKey<FormState>();
  late final _reason = TextEditingController(text: widget.initialReason);
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BaseFormDialog(
    title: 'Не доставлено',
    submitButtonText: 'Применить',
    formKey: _form,
    onSubmit: () {
      if (_form.currentState!.validate()) {
        Navigator.of(context).pop(_reason.text.trim());
      }
    },
    children: [
      const Text(
        'Товары останутся в маршруте, но покупка не войдёт в продажи и начисления.',
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _reason,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        maxLength: 1000,
        decoration: const InputDecoration(
          labelText: 'Причина',
          border: OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Укажите причину' : null,
      ),
    ],
  );
}

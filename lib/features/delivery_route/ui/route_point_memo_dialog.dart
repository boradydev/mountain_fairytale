import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';

class RoutePointMemoDialog extends StatefulWidget {
  final String initialMemo;
  const RoutePointMemoDialog({super.key, this.initialMemo = ''});
  @override
  State<RoutePointMemoDialog> createState() => _RoutePointMemoDialogState();
}

class _RoutePointMemoDialogState extends State<RoutePointMemoDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _memo = TextEditingController(
    text: widget.initialMemo,
  );
  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BaseFormDialog(
    title: 'Памятка водителю',
    submitButtonText: 'Сохранить',
    formKey: _form,
    onSubmit: () {
      if (_form.currentState!.validate()) {
        Navigator.of(context).pop(_memo.text.trim());
      }
    },
    children: [
      const Text(
        'Памятка относится к этому клиенту в данном маршруте и печатается после формы оплаты.',
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _memo,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        maxLength: 1000,
        decoration: const InputDecoration(
          labelText: 'Текст памятки',
          hintText: 'Например, позвонить за час',
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );
}

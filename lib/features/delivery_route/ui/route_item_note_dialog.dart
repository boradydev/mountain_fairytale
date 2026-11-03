import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';

class RouteItemNoteDialog extends StatefulWidget {
  final String initialNote;

  const RouteItemNoteDialog({super.key, this.initialNote = ''});

  @override
  State<RouteItemNoteDialog> createState() => _RouteItemNoteDialogState();
}

class _RouteItemNoteDialogState extends State<RouteItemNoteDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _note = TextEditingController(
    text: widget.initialNote,
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BaseFormDialog(
    title: 'Уточнение для водителя',
    submitButtonText: 'Сохранить',
    formKey: _form,
    onSubmit: () {
      if (_form.currentState!.validate()) {
        Navigator.of(context).pop(_note.text.trim());
      }
    },
    children: [
      const Text(
        'Уточнение относится к этой позиции у клиента в данном маршруте.',
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _note,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        maxLength: 1000,
        decoration: const InputDecoration(
          labelText: 'Текст уточнения',
          hintText: 'Например, забрать кулер',
          border: OutlineInputBorder(),
        ),
      ),
    ],
  );
}

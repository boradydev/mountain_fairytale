import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';
import 'package:mountain_fairytale/presentation/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/presentation/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/presentation/screens/common/sales_rep_dialog.dart';

class SalesRepSelectDialog extends StatefulWidget {
  final List<SalesRepresentative> reps;

  const SalesRepSelectDialog({super.key, required this.reps});

  @override
  State<SalesRepSelectDialog> createState() => _SalesRepSelectDialogState();
}

class _SalesRepSelectDialogState extends State<SalesRepSelectDialog> {
  final _formKey = GlobalKey<FormState>();
  SalesRepresentative? _selectedRep;

  @override
  Widget build(BuildContext context) {
    return BaseFormDialog(
      title: 'Выберите представителя',
      submitButtonText: 'Выбрать',
      formKey: _formKey,
      onSubmit: () {
        if (_formKey.currentState!.validate()) {
          Navigator.of(context).pop(_selectedRep);
        }
      },
      children: [
        AppDropdown<SalesRepresentative>(
          label: 'Кому передать клиентов?',
          items: widget.reps,
          value: _selectedRep,
          prefixIcon: Icons.badge_outlined,
          hint: 'Выберите представителя',
          itemLabelBuilder: (rep) => rep.name,
          onChanged: (val) {
            setState(() {
              _selectedRep = val;
            });
          },
          onAdd: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (_) => const SalesRepDialog(),
            );

            if (result == true && mounted) {
              // В данном контексте список reps передается извне,
              // поэтому после добавления нужно либо обновить список в родителе,
              // либо полагаться на то, что родитель переоткроет диалог.
              // Но для консистентности с ClientDialog, мы просто закрываем текущий
              // выбор, чтобы обновить данные.
              Navigator.of(context).pop(null);
            }
          },
          onEdit: _selectedRep == null
              ? null
              : () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (_) => SalesRepDialog(salesRep: _selectedRep),
                  );

                  if (result == true && mounted) {
                    // После редактирования обновляем выбор, если представитель не был удален
                    setState(() {});
                  }
                },
        ),
      ],
    );
  }
}

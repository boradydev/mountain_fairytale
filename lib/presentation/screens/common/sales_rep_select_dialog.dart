import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/infra/repos/sales_representatives/models/sales_representative_model.dart';
import 'package:mountain_fairytale/presentation/providers/sales_representative_provider.dart';
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
        Consumer<SalesRepresentativeProvider>(
          builder: (context, provider, child) {
            return AppDropdown<SalesRepresentative>(
              label: 'Кому передать клиентов?',
              items: provider.salesRepresentatives,
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
                  // Получаем последнего добавленного представителя (он первый в списке)
                  final lastAddedRep = provider.salesRepresentatives.first;
                  setState(() {
                    _selectedRep = lastAddedRep;
                  });
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
                        setState(() {});
                      }
                    },
            );
          },
        ),
      ],
    );
  }
}

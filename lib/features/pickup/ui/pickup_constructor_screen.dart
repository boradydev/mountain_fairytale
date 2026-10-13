import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_constructor_provider.dart';
import 'package:mountain_fairytale/features/pickup/ui/pickup_meta_panel.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/delivery_document_editor.dart';

class PickupConstructorScreen extends StatelessWidget {
  final String? existingPickupId;
  final DateTime? initialDate;
  final VoidCallback? onDocumentChanged;
  const PickupConstructorScreen({
    super.key,
    this.existingPickupId,
    this.initialDate,
    this.onDocumentChanged,
  });
  @override
  Widget build(BuildContext context) {
    final provider = context.read<PickupConstructorProvider>();
    return DeliveryDocumentEditor(
      provider: provider,
      title: 'Самовывоз',
      initialize: () async {
        if (existingPickupId == null) {
          provider.resetForm();
          if (initialDate != null) provider.setDate(initialDate!);
          await provider.loadDirectories();
        } else {
          await provider.loadExistingPickupById(existingPickupId!);
        }
      },
      save: provider.savePickup,
      changeActive: provider.changeDocumentActive,
      onDocumentChanged: onDocumentChanged,
      metaBuilder: (key) => PickupMetaPanel(formKey: key),
    );
  }
}

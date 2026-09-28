import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/audit_log/models/audit_event_model.dart';

class AuditEventRow extends StatelessWidget {
  final AuditEvent event;

  const AuditEventRow({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final config = _AuditActionConfig.from(
      event.action,
      colorScheme,
    );

    final changes = event.changes.values.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(
              _formatTime(event.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            config.icon,
            size: 19,
            color: config.color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: event.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: config.actionText,
                        style: TextStyle(
                          color: config.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: _entityTypeText(event.entityType),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: event.entityName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (changes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...changes.map(
                    (change) => _ChangeRow(change: change),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();

    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _entityTypeText(String type) {
    return switch (type) {
      'product' => 'товар',
      'client' => 'клиента',
      'driver' => 'водителя',
      'car' => 'автомобиль',
      _ => type,
    };
  }
}

class _ChangeRow extends StatelessWidget {
  final AuditChange change;

  const _ChangeRow({
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: change.oldValue ?? '—',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          TextSpan(
            text: ' → ',
            style: TextStyle(
              color: colorScheme.outline,
            ),
          ),
          TextSpan(
            text: change.newValue ?? '—',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditActionConfig {
  final IconData icon;
  final Color color;
  final String actionText;

  const _AuditActionConfig({
    required this.icon,
    required this.color,
    required this.actionText,
  });

  factory _AuditActionConfig.from(
    AuditAction action,
    ColorScheme colorScheme,
  ) {
    return switch (action) {
      AuditAction.created => _AuditActionConfig(
        icon: Icons.add_circle_outline,
        color: colorScheme.primary,
        actionText: 'создал',
      ),
      AuditAction.updated => _AuditActionConfig(
        icon: Icons.edit_outlined,
        color: colorScheme.primary,
        actionText: 'изменил',
      ),
      AuditAction.deleted => _AuditActionConfig(
        icon: Icons.delete_outline,
        color: colorScheme.error,
        actionText: 'удалил',
      ),
    };
  }
}

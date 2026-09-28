import 'package:mountain_fairytale/presentation/providers/abcs/repos/audit_log_contracts.dart';

class DemoAuditLogDataSource implements AuditLogDataSource {
  late final List<Map<String, dynamic>> _events = _generateEvents();

  @override
  Future<List<Map<String, dynamic>>> getAuditEvents({
    String? search,
    required int offset,
    required int limit,
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));

    final normalizedSearch = search?.trim().toLowerCase();

    List<Map<String, dynamic>> result = _events;

    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      result = result.where((event) {
        final text = [
          event['userName'],
          event['entityName'],
          event['entityType'],
          event['action'],
          ..._changeValues(event['changes']),
        ].join(' ').toLowerCase();

        return text.contains(normalizedSearch);
      }).toList();
    }

    final start = offset.clamp(0, result.length);

    final end = (start + limit).clamp(0, result.length);

    if (start >= end) {
      return [];
    }

    return result.sublist(start, end);
  }

  List<String> _changeValues(dynamic changes) {
    if (changes is! Map) {
      return [];
    }

    final values = <String>[];

    for (final value in changes.values) {
      if (value is Map) {
        values.add(value['oldValue']?.toString() ?? '');
        values.add(value['newValue']?.toString() ?? '');
      }
    }

    return values;
  }

  List<Map<String, dynamic>> _generateEvents() {
    final users = [
      (1, 'Иванов Иван Иванович'),
      (2, 'Петров Пётр Сергеевич'),
      (3, 'Сидорова Анна Викторовна'),
      (4, 'Кузнецов Алексей Дмитриевич'),
      (5, 'Орлова Мария Андреевна'),
    ];

    final products = [
      'Вода 19 л',
      'Вода Донум 19 л',
      'Вода 5 л',
      'Вода 1,5 л',
      'Стаканы 200 мл',
      'Кулер напольный',
    ];

    final clients = [
      'ООО Ромашка',
      'ООО Север',
      'ИП Иванов',
      'ООО Альфа',
      'ООО Стройсервис',
      'Магазин «У дома»',
      'ООО Техноцентр',
      'Администрация города',
    ];

    final drivers = [
      'Иванов Алексей Петрович',
      'Смирнов Сергей Викторович',
      'Кузнецов Дмитрий Андреевич',
    ];

    final cars = [
      'Газель А123ББ',
      'Газель В456ВВ',
      'Газель С789СС',
    ];

    final events = <Map<String, dynamic>>[];

    final now = DateTime.now();

    for (var i = 0; i < 120; i++) {
      final user = users[i % users.length];
      final actionIndex = i % 3;

      final action = switch (actionIndex) {
        0 => 'created',
        1 => 'updated',
        _ => 'deleted',
      };

      final entityIndex = i % 4;

      String entityType;
      String entityName;
      int entityId;

      switch (entityIndex) {
        case 0:
          entityType = 'product';
          entityName = products[i % products.length];
          entityId = (i % products.length) + 1;
          break;

        case 1:
          entityType = 'client';
          entityName = clients[i % clients.length];
          entityId = (i % clients.length) + 1;
          break;

        case 2:
          entityType = 'driver';
          entityName = drivers[i % drivers.length];
          entityId = (i % drivers.length) + 1;
          break;

        default:
          entityType = 'car';
          entityName = cars[i % cars.length];
          entityId = (i % cars.length) + 1;
          break;
      }

      final createdAt = now.subtract(
        Duration(
          minutes: i * 47,
          seconds: i * 13,
        ),
      );

      final Map<String, dynamic> changes;

      if (action == 'updated') {
        final oldName = entityType == 'product'
            ? products[(i + 1) % products.length]
            : '$entityName — старое значение';

        changes = {
          'name': {
            'oldValue': oldName,
            'newValue': entityName,
          },
        };
      } else {
        changes = {};
      }

      events.add({
        'id': 10000 - i,
        'createdAt': createdAt.toIso8601String(),
        'userId': user.$1,
        'userName': user.$2,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'entityName': entityName,
        'changes': changes,
      });
    }

    return events;
  }
}

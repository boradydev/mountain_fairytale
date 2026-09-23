import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/repos/clients/sources/demo_data.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/sales_representative.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/sales_representative_client.dart';

class DemoSalesRepresentativeClientDataSource
    implements SalesRepresentativeClientDataSource {
  final DemoClientDataSource clientDataSource;
  final SalesRepresentativeRepository salesRepRepo;

  static const _clientsPath =
      'assets/demo/sales_representative_clients/sales_representative_clients_data.json';

  DemoSalesRepresentativeClientDataSource({
    required this.clientDataSource,
    required this.salesRepRepo,
  });

  @override
  Future<List<Map<String, dynamic>>> getClients({
    required int salesRepresentativeId,
    required String dateFrom,
    required String dateTo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final jsonString = await rootBundle.loadString(_clientsPath);
    final List<dynamic> data = jsonDecode(jsonString);

    // Получаем всех клиентов для обогащения данных (имена, телефоны)
    final allClients = await clientDataSource.getAllClients();

    return data
        .where((e) => e['salesRepresentativeId'] == salesRepresentativeId)
        .map((e) {
          final item = Map<String, dynamic>.from(e);
          final clientId = item['clientId'] as int;

          // Ищем данные клиента в общем списке
          final clientInfo = allClients.firstWhere(
            (c) => c['id'] == clientId,
            orElse: () => {'name': 'Неизвестный клиент', 'phone': 'Нет данных'},
          );

          // Добавляем недостающие поля, которые ожидает модель SalesRepresentativeClient
          item['clientName'] = clientInfo['name'];
          item['phone'] = clientInfo['phone'];
          item['commissionAmount'] = e['commissionAmount'] ?? 0.0;

          // Приводим 'amount' из JSON к 'totalSalesAmount' для модели
          if (item.containsKey('amount')) {
            item['totalSalesAmount'] = item['amount'];
          }

          return item;
        })
        .toList();
  }

  @override
  Future<void> assignClientsToSalesRepresentative({
    required int fromId,
    required int toId,
  }) async {
    final rep = await salesRepRepo.getSalesRepresentativeById(toId);
    await clientDataSource.massUpdateSalesRepresentative(
      fromId: fromId,
      toId: toId,
      toName: rep.name,
    );
  }

  @override
  Future<void> clearSalesRepresentativeClients({
    required int salesRepresentativeId,
  }) async {
    await clientDataSource.massUpdateSalesRepresentative(
      fromId: salesRepresentativeId,
      toId: null,
      toName: null,
    );
  }
}

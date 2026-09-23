import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mountain_fairytale/infra/repos/clients/sources/demo_data.dart';
import 'package:mountain_fairytale/infra/repos/sales_representative_clients/repo.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/sales_representative.dart';

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

    final from = DateTime.parse(dateFrom);
    final to = DateTime.parse(dateTo);

    return data
        .where((e) {
          if (e['salesRepresentativeId'] != salesRepresentativeId) return false;
          if (e['date'] == null) return true;

          final date = DateTime.parse(e['date']);
          // Используем сравнение, которое включает границы периода (date >= from && date <= to)
          return !date.isBefore(from) && !date.isAfter(to);
        })
        .cast<Map<String, dynamic>>()
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

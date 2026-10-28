import 'package:mountain_fairytale/features/commissions/data/commission_amount.dart';

List<T> _rows<T>(
  Map<String, dynamic> json,
  String field,
  T Function(Map<String, dynamic>) decode,
) => (json[field] as List)
    .map((row) => decode(Map<String, dynamic>.from(row as Map)))
    .toList(growable: false);

class CommissionRate {
  final String percent;
  final CommissionAmount turnover;
  final CommissionAmount payable;
  const CommissionRate(this.percent, this.turnover, this.payable);
  factory CommissionRate.fromJson(Map<String, dynamic> json) => CommissionRate(
    json['commissionPercent'].toString(),
    CommissionAmount.fromJson(json['turnoverBase']),
    CommissionAmount.fromJson(json['commissionPayable']),
  );
}

class RepresentativeCommission {
  final String id;
  final String name;
  final bool isActive;
  final int assignedClientsCount;
  final int clientsCount;
  final int ordersCount;
  final CommissionAmount turnover;
  final CommissionAmount payable;
  final List<CommissionRate> rates;
  const RepresentativeCommission({
    required this.id,
    required this.name,
    required this.isActive,
    required this.assignedClientsCount,
    required this.clientsCount,
    required this.ordersCount,
    required this.turnover,
    required this.payable,
    required this.rates,
  });
  factory RepresentativeCommission.fromJson(Map<String, dynamic> json) =>
      RepresentativeCommission(
        id: json['salesRepresentativeId'] as String,
        name: json['salesRepresentativeName'] as String,
        isActive: json['isActive'] as bool,
        assignedClientsCount: json['assignedClientsCount'] as int,
        clientsCount: json['clientsCount'] as int,
        ordersCount: json['ordersCount'] as int,
        turnover: CommissionAmount.fromJson(json['turnover']),
        payable: CommissionAmount.fromJson(json['commissionPayable']),
        rates: _rows(json, 'commissionRateBreakdown', CommissionRate.fromJson),
      );
}

class EmployeeCommission {
  final String id;
  final String name;
  final bool isActive;
  final CommissionAmount turnover;
  final CommissionAmount payable;
  final List<CommissionRate> rates;
  const EmployeeCommission({
    required this.id,
    required this.name,
    required this.isActive,
    required this.turnover,
    required this.payable,
    required this.rates,
  });
  factory EmployeeCommission.fromJson(Map<String, dynamic> json) =>
      EmployeeCommission(
        id: json['employeeId'] as String,
        name: json['username'] as String,
        isActive: json['isActive'] as bool,
        turnover: CommissionAmount.fromJson(json['turnoverBase']),
        payable: CommissionAmount.fromJson(json['commissionPayable']),
        rates: _rows(json, 'commissionRateBreakdown', CommissionRate.fromJson),
      );
}

class ClientCommission {
  final String id;
  final String name;
  final String phone;
  final bool isActive;
  final bool isCurrentlyAssigned;
  final int ordersCount;
  final String? lastOrderDate;
  final CommissionAmount turnover;
  final CommissionAmount payable;
  final List<CommissionRate> rates;
  const ClientCommission({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
    required this.isCurrentlyAssigned,
    required this.ordersCount,
    required this.lastOrderDate,
    required this.turnover,
    required this.payable,
    required this.rates,
  });
  factory ClientCommission.fromJson(Map<String, dynamic> json) =>
      ClientCommission(
        id: json['clientId'] as String,
        name: json['clientName'] as String,
        phone: json['phone'] as String,
        isActive: json['isActive'] as bool,
        isCurrentlyAssigned: json['isCurrentlyAssigned'] as bool,
        ordersCount: json['ordersCount'] as int,
        lastOrderDate: json['lastOrderDate'] as String?,
        turnover: CommissionAmount.fromJson(json['turnover']),
        payable: CommissionAmount.fromJson(json['commissionPayable']),
        rates: _rows(json, 'commissionRateBreakdown', CommissionRate.fromJson),
      );
}

class RepresentativeCommissionDetails {
  final RepresentativeCommission representative;
  final List<ClientCommission> clients;
  const RepresentativeCommissionDetails(this.representative, this.clients);
  factory RepresentativeCommissionDetails.fromJson(Map<String, dynamic> json) =>
      RepresentativeCommissionDetails(
        RepresentativeCommission.fromJson(json),
        _rows(json, 'clients', ClientCommission.fromJson),
      );
  BigInt get turnoverCents => representative.turnover.cents;
  BigInt get payableCents => representative.payable.cents;
}

class CommissionReport {
  final List<RepresentativeCommission> representatives;
  final List<EmployeeCommission> employees;
  final CommissionAmount unassignedTurnover;
  final CommissionAmount employeeTurnover;
  const CommissionReport({
    required this.representatives,
    required this.employees,
    required this.unassignedTurnover,
    this.employeeTurnover = CommissionAmount.zero,
  });
  factory CommissionReport.fromJson(Map<String, dynamic> json) =>
      CommissionReport(
        representatives: _rows(
          json,
          'salesRepresentatives',
          RepresentativeCommission.fromJson,
        ),
        employees: _rows(json, 'employees', EmployeeCommission.fromJson),
        unassignedTurnover: CommissionAmount.fromJson(
          json['summary']['unassignedTurnover'],
        ),
        employeeTurnover: CommissionAmount.fromJson(
          json['summary']['employeeTurnover'],
        ),
      );
  BigInt get representativesPayable =>
      representatives.fold(BigInt.zero, (sum, row) => sum + row.payable.cents);
  BigInt get employeesPayable =>
      employees.fold(BigInt.zero, (sum, row) => sum + row.payable.cents);
  BigInt get totalPayable => representativesPayable + employeesPayable;
  BigInt get representedTurnover =>
      representatives.fold(BigInt.zero, (sum, row) => sum + row.turnover.cents);
  BigInt get totalTurnover => representedTurnover + unassignedTurnover.cents;
}

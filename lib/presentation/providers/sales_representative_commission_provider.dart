import 'package:flutter/material.dart';
import 'package:mountain_fairytale/infra/repos/sales_representative_commissions/models/sales_representative_commission_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/sales_representative_commission.dart';

enum SalesRepresentativeCommissionStatus { initial, loading, success, failure }

class SalesRepresentativeCommissionProvider extends ChangeNotifier {
  final SalesRepresentativeCommissionRepository _repository;

  SalesRepresentativeCommissionProvider(this._repository);

  SalesRepresentativeCommissionStatus _status =
      SalesRepresentativeCommissionStatus.initial;

  List<SalesRepresentativeCommission> _commissions = const [];

  double _totalCommissionAmount = 0;

  String _errorMessage = '';

  DateTime _dateFrom = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  DateTime _dateTo = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    0,
  );

  SalesRepresentativeCommissionStatus get status => _status;

  List<SalesRepresentativeCommission> get commissions => _commissions;

  double get totalCommissionAmount => _totalCommissionAmount;

  String get errorMessage => _errorMessage;

  DateTime get dateFrom => _dateFrom;

  DateTime get dateTo => _dateTo;

  Future<void> fetchCommissions() async {
    _status = SalesRepresentativeCommissionStatus.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final report = await _repository.getSalesRepresentativeCommissions(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      _commissions = report.commissions;
      _totalCommissionAmount = report.totalCommissionAmount;

      _status = SalesRepresentativeCommissionStatus.success;
    } catch (e) {
      _errorMessage = e.toString();
      _status = SalesRepresentativeCommissionStatus.failure;
    }

    notifyListeners();
  }

  Future<void> setMonth(DateTime month) async {
    _dateFrom = DateTime(month.year, month.month, 1);
    _dateTo = DateTime(month.year, month.month + 1, 0);

    await fetchCommissions();
  }
}

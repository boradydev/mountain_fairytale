import 'package:flutter/foundation.dart';
import 'package:mountain_fairytale/infra/repos/audit_log/models/audit_event_model.dart';
import 'package:mountain_fairytale/presentation/providers/abcs/repos/audit_log_contracts.dart';

enum AuditLogStatus {
  initial,
  loading,
  success,
  failure,
}

class AuditLogProvider extends ChangeNotifier {
  final AuditLogRepository _repository;

  AuditLogProvider(this._repository);

  static const int _pageSize = 50;

  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  String _search = '';

  List<AuditEvent> _events = const [];

  AuditLogStatus _status = AuditLogStatus.initial;
  String _errorMessage = '';

  List<AuditEvent> get events => _events;

  AuditLogStatus get status => _status;

  String get errorMessage => _errorMessage;

  bool get isLoading => _status == AuditLogStatus.loading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasMore => _hasMore;

  bool get hasError => _status == AuditLogStatus.failure;

  bool get isEmpty => _status == AuditLogStatus.success && _events.isEmpty;

  String get search => _search;

  Future<void> fetchEvents() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    _isLoadingMore = true;

    if (_events.isEmpty) {
      _status = AuditLogStatus.loading;
    }

    notifyListeners();

    try {
      final newEvents = await _repository.getAuditEvents(
        search: _search.isEmpty ? null : _search,
        offset: _offset,
        limit: _pageSize,
      );

      _events = [
        ..._events,
        ...newEvents,
      ];

      _offset += newEvents.length;

      if (newEvents.length < _pageSize) {
        _hasMore = false;
      }

      _status = AuditLogStatus.success;
      _errorMessage = '';
    } catch (e) {
      _errorMessage = e.toString();

      if (_events.isEmpty) {
        _status = AuditLogStatus.failure;
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> searchEvents(String value) async {
    final normalized = value.trim();

    if (_search == normalized) {
      return;
    }

    _search = normalized;

    _offset = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _events = const [];
    _status = AuditLogStatus.initial;
    _errorMessage = '';

    notifyListeners();

    await fetchEvents();
  }

  Future<void> refreshEvents() async {
    _offset = 0;
    _hasMore = true;
    _isLoadingMore = false;
    _events = const [];
    _status = AuditLogStatus.initial;
    _errorMessage = '';

    await fetchEvents();
  }
}

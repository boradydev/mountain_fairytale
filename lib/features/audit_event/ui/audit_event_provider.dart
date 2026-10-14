import 'package:mountain_fairytale/core/network/api_exception.dart';
import 'package:mountain_fairytale/core/state/safe_change_notifier.dart';
import 'package:mountain_fairytale/features/audit_event/data/audit_events_model.dart';
import 'package:mountain_fairytale/features/audit_event/audit_events_abcs.dart';

enum AuditLogStatus { initial, loading, success, failure }

class AuditLogProvider extends SafeChangeNotifier {
  final AuditLogRepository _repository;
  AuditLogProvider(this._repository);
  static const int _pageSize = 50;
  String? _cursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _generation = 0;
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
  bool get hasError => _errorMessage.isNotEmpty;
  bool get isEmpty => _status == AuditLogStatus.success && _events.isEmpty;
  String get search => _search;
  List<AuditOperation> get operations {
    final groups = <String, List<AuditEvent>>{};
    for (final event in _events) {
      groups.putIfAbsent(event.operationId, () => []).add(event);
    }
    return groups.entries
        .map((entry) => AuditOperation(entry.key, entry.value))
        .toList();
  }

  Future<void> fetchEvents() async {
    if (_isLoadingMore || !_hasMore) return;
    final generation = _generation;
    final cursor = _cursor;
    _isLoadingMore = true;
    if (_events.isEmpty) _status = AuditLogStatus.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      final page = await _repository.getAuditEvents(
        search: _search.isEmpty ? null : _search,
        cursor: cursor,
        limit: _pageSize,
      );
      if (generation != _generation) return;
      final combined = cursor == null
          ? page.events
          : [..._events, ...page.events];
      final seen = <String>{};
      _events = combined.where((event) => seen.add(event.eventId)).toList();
      _cursor = page.nextCursor;
      _hasMore = _cursor != null && page.events.isNotEmpty;
      _status = AuditLogStatus.success;
    } catch (error) {
      if (generation != _generation) return;
      if (error is ApiException && error.statusCode == 422 && cursor != null) {
        await refreshEvents();
        return;
      }
      _errorMessage = error.toString();
      if (_events.isEmpty) _status = AuditLogStatus.failure;
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> searchEvents(String value) async {
    final normalized = value.trim();
    if (_search == normalized) return;
    _search = normalized;
    _events = const [];
    await refreshEvents();
  }

  Future<void> refreshEvents() async {
    _generation++;
    _cursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    await fetchEvents();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

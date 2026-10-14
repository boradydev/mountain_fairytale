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
  String? _latestCursor;
  String? _updatesCursor;
  bool _isCheckingUpdates = false;
  List<AuditEvent> _pendingEvents = const [];
  String _updatesError = '';
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _generation = 0;
  String _search = '';
  AuditFilters _filters = const AuditFilters();
  AuditFilters get filters => _filters;
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
  bool get supportsUpdates =>
      _repository is AuditUpdatesRepository &&
      (_repository as AuditUpdatesRepository).supportsUpdates;
  bool get isCheckingUpdates => _isCheckingUpdates;
  bool get hasPendingEvents => _pendingEvents.isNotEmpty;
  bool get hasMoreUpdates => _updatesCursor != null;
  String get updatesError => _updatesError;
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
      final repository = _repository;
      final page = !_filters.isEmpty && repository is AuditFilteredRepository
          ? await (repository as AuditFilteredRepository)
                .getFilteredAuditEvents(
                  filters: _filters,
                  search: _search.isEmpty ? null : _search,
                  cursor: cursor,
                  limit: _pageSize,
                )
          : await repository.getAuditEvents(
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
      if (cursor == null) _latestCursor = page.latestCursor;
      _hasMore = _cursor != null && page.events.isNotEmpty;
      _status = AuditLogStatus.success;
    } catch (error) {
      if (generation != _generation) return;
      if (error is ApiException && error.statusCode == 422 && cursor != null) {
        _resetPages();
        await fetchEvents();
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

  Future<void> setFilters(AuditFilters filters) async {
    _filters = filters;
    _search = '';
    _events = const [];
    _resetPages();
    await fetchEvents();
  }

  Future<void> refreshEvents() async {
    if (_events.isNotEmpty && _latestCursor != null && supportsUpdates) {
      await checkForUpdates();
      showPendingEvents();
      return;
    }
    _resetPages();
    await fetchEvents();
  }

  void _resetPages() {
    _generation++;
    _cursor = null;
    _latestCursor = null;
    _updatesCursor = null;
    _pendingEvents = const [];
    _updatesError = '';
    _isCheckingUpdates = false;
    _hasMore = true;
    _isLoadingMore = false;
  }

  Future<void> checkForUpdates({bool Function()? shouldContinue}) async {
    if (!supportsUpdates ||
        _latestCursor == null ||
        _isCheckingUpdates ||
        isLoading) {
      return;
    }
    final repository = _repository as AuditUpdatesRepository;
    final generation = _generation;
    _isCheckingUpdates = true;
    _updatesError = '';
    notifyListeners();
    try {
      // Ограничиваем одну проверку; большой поток продолжаем со следующего курсора.
      for (var pageNumber = 0; pageNumber < 5; pageNumber++) {
        if (shouldContinue != null && !shouldContinue()) break;
        final page = await repository.getNewAuditEvents(
          after: _updatesCursor ?? _latestCursor!,
          search: _search.isEmpty ? null : _search,
          limit: _pageSize,
          filters: _filters,
        );
        if (generation != _generation) return;
        final seen = _events.map((event) => event.eventId).toSet();
        _pendingEvents = [
          ..._pendingEvents,
          ...page.events,
        ].where((event) => seen.add(event.eventId)).toList();
        _latestCursor = page.latestCursor ?? _latestCursor;
        _updatesCursor = page.nextCursor;
        if (_updatesCursor == null) break;
      }
    } catch (error) {
      if (generation != _generation) return;
      _updatesError = 'Не удалось проверить новые события';
    } finally {
      if (generation == _generation) {
        _isCheckingUpdates = false;
        notifyListeners();
      }
    }
  }

  void showPendingEvents() {
    if (_pendingEvents.isEmpty) return;
    final seen = <String>{};
    _events =
        [
          ..._pendingEvents,
          ..._events,
        ].where((event) => seen.add(event.eventId)).toList()..sort((a, b) {
          final time = b.createdAt.compareTo(a.createdAt);
          return time == 0 ? b.eventId.compareTo(a.eventId) : time;
        });
    _pendingEvents = const [];
    _status = AuditLogStatus.success;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}

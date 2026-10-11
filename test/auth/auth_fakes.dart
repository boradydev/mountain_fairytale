import 'dart:async';
import 'dart:convert';

import 'package:mountain_fairytale/infra/auth/token_storage.dart';
import 'package:mountain_fairytale/infra/http/http_transport.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/auth_tokens_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/auth_user_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/current_employee_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/repo.dart';

const originalTokens = AuthTokensModel(
  accessToken: 'original-access',
  refreshToken: 'original-refresh',
);
const renewedTokens = AuthTokensModel(
  accessToken: 'renewed-access',
  refreshToken: 'renewed-refresh',
);
const employee = CurrentEmployeeModel(
  employeeId: '019a1111-1111-7111-8111-111111111111',
  username: 'manager',
  role: 'employee',
);

class MemoryTokenStorage implements TokenStorage {
  String? access;
  String? refresh;
  bool failSave = false;
  Completer<void>? saveGate;
  Completer<void>? saveStarted;
  Completer<void>? clearGate;

  @override
  Future<String?> getAccessToken() async => access;

  @override
  Future<String?> getRefreshToken() async => refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (failSave) throw StateError('Storage write failed');
    saveStarted?.complete();
    await saveGate?.future;
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    await clearGate?.future;
    access = null;
    refresh = null;
  }
}

class FakeAuthRepository implements AuthRepository {
  int loginCalls = 0;
  int refreshCalls = 0;
  int meCalls = 0;
  int logoutCalls = 0;
  String? lastPassword;
  String? logoutAccess;
  Object? usersError;
  List<AuthUserModel> users = [const AuthUserModel(username: 'manager')];

  Future<AuthTokensModel> Function(String)? onRefresh;
  Future<CurrentEmployeeModel> Function(String)? onGetMe;
  Future<void> Function(String)? onLogout;
  Future<AuthTokensModel> Function()? onLogin;
  Future<void> Function()? onChangePassword;

  @override
  Future<AuthTokensModel> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    lastPassword = password;
    return onLogin == null ? originalTokens : await onLogin!();
  }

  @override
  Future<AuthTokensModel> refresh({required String refreshToken}) async {
    refreshCalls++;
    return onRefresh == null ? renewedTokens : await onRefresh!(refreshToken);
  }

  @override
  Future<List<AuthUserModel>> getUsers() async {
    if (usersError != null) throw usersError!;
    return users;
  }

  @override
  Future<CurrentEmployeeModel> getMe({required String accessToken}) async {
    meCalls++;
    return onGetMe == null ? employee : await onGetMe!(accessToken);
  }

  @override
  Future<void> changePassword({
    required String accessToken,
    required String password,
  }) async {
    lastPassword = password;
    if (onChangePassword != null) await onChangePassword!();
  }

  @override
  Future<void> logout({required String accessToken}) async {
    logoutCalls++;
    logoutAccess = accessToken;
    if (onLogout != null) await onLogout!(accessToken);
  }
}

class RecordedRequest {
  final String method;
  final String path;
  final Map<String, String>? headers;
  final Object? body;

  RecordedRequest(this.method, this.path, this.headers, this.body);
}

class RecordingTransport extends HttpTransport {
  final requests = <RecordedRequest>[];
  late Future<HttpTransportResponse> Function(RecordedRequest) respond;

  RecordingTransport() : super(baseUrl: 'http://unused.invalid');

  Future<HttpTransportResponse> _record(
    String method,
    String path,
    Map<String, String>? headers,
    Object? body,
  ) {
    final request = RecordedRequest(method, path, headers, body);
    requests.add(request);
    return respond(request);
  }

  @override
  Future<HttpTransportResponse> get(
    String path, {
    Map<String, String>? headers,
  }) => _record('GET', path, headers, null);

  @override
  Future<HttpTransportResponse> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => _record('POST', path, headers, body);

  @override
  Future<HttpTransportResponse> put(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) => _record('PUT', path, headers, body);
}

HttpTransportResponse envelope(Object? data) => HttpTransportResponse(
  statusCode: 200,
  body: jsonEncode({
    'offset': null,
    'limit': null,
    'total': null,
    'message': null,
    'data': data,
  }),
);

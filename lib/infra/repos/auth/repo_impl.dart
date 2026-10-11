import 'package:mountain_fairytale/infra/repos/auth/models/auth_tokens_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/auth_user_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/current_employee_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/repo.dart';
import 'package:mountain_fairytale/infra/repos/auth/sources/api_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApiDataSource _dataSource;

  AuthRepositoryImpl({required this._dataSource});

  @override
  Future<AuthTokensModel> login({
    required String username,
    required String password,
  }) => _dataSource.login(username: username, password: password);

  @override
  Future<AuthTokensModel> refresh({required String refreshToken}) =>
      _dataSource.refresh(refreshToken: refreshToken);

  @override
  Future<List<AuthUserModel>> getUsers() => _dataSource.getUsers();

  @override
  Future<CurrentEmployeeModel> getMe({required String accessToken}) =>
      _dataSource.getMe(accessToken: accessToken);

  @override
  Future<void> changePassword({
    required String accessToken,
    required String password,
  }) =>
      _dataSource.changePassword(accessToken: accessToken, password: password);

  @override
  Future<void> logout({required String accessToken}) =>
      _dataSource.logout(accessToken: accessToken);
}

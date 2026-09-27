import 'package:mountain_fairytale/infra/repos/auth/models/auth_tokens_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/repo.dart';
import 'package:mountain_fairytale/infra/repos/auth/sources/api_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApiDataSource _dataSource;

  AuthRepositoryImpl({
    required this._dataSource,
  });

  @override
  Future<AuthTokensModel> login({
    required String username,
    required String password,
  }) {
    return _dataSource.login(
      username: username,
      password: password,
    );
  }

  @override
  Future<AuthTokensModel> refresh({
    required String refreshToken,
  }) {
    return _dataSource.refresh(
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> logout({
    required String refreshToken,
  }) {
    return _dataSource.logout(
      refreshToken: refreshToken,
    );
  }
}

import 'package:mountain_fairytale/infra/repos/auth/models/auth_tokens_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/auth_user_model.dart';
import 'package:mountain_fairytale/infra/repos/auth/models/current_employee_model.dart';

abstract interface class AuthRepository {
  Future<AuthTokensModel> login({
    required String username,
    required String password,
  });

  Future<AuthTokensModel> refresh({required String refreshToken});

  Future<List<AuthUserModel>> getUsers();

  Future<CurrentEmployeeModel> getMe({required String accessToken});

  Future<void> changePassword({
    required String accessToken,
    required String password,
  });

  Future<void> logout({required String accessToken});
}

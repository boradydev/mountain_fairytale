import 'package:mountain_fairytale/infra/repos/auth/models/auth_tokens_model.dart';

abstract interface class AuthRepository {
  Future<AuthTokensModel> login({
    required String username,
    required String password,
  });

  Future<AuthTokensModel> refresh({
    required String refreshToken,
  });

  Future<void> logout({
    required String refreshToken,
  });
}

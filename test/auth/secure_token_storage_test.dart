import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/infra/auth/secure_token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('writes and reads the token pair as one secure record', () async {
    final storage = SecureTokenStorage();
    await storage.saveTokens(accessToken: 'access', refreshToken: 'refresh');
    expect(await storage.getAccessToken(), 'access');
    expect(await storage.getRefreshToken(), 'refresh');
    final records = await const FlutterSecureStorage().readAll();
    expect(records.keys, ['auth_tokens']);
    expect(jsonDecode(records['auth_tokens']!), {
      'accessToken': 'access',
      'refreshToken': 'refresh',
    });
  });

  test(
    'previously stored tokens survive upgrade and are removed on logout',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_access_token': 'old-access',
        'auth_refresh_token': 'old-refresh',
      });
      final storage = SecureTokenStorage();
      expect(await storage.getRefreshToken(), 'old-refresh');
      await storage.saveTokens(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
      );
      expect(await storage.getRefreshToken(), 'new-refresh');
      await storage.clear();
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.getAccessToken(), isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/app_updates/data/update_release.dart';

void main() {
  const release = UpdateRelease(
    version: '1.2.0',
    buildNumber: 20,
    description: 'Исправления',
  );
  test('semantic version takes precedence over build count', () {
    expect(release.isNewerThan('1.1.9+999'), isTrue);
    expect(release.isNewerThan('1.2.0+19'), isTrue);
    expect(release.isNewerThan('1.2.0+20'), isFalse);
    expect(release.isNewerThan('1.2.1+1'), isFalse);
    expect(release.isNewerThan('invalid'), isFalse);
  });
  test('rejects malformed or unsupported release metadata', () {
    for (final override in [
      {'schemaVersion': 2},
      {'version': 'v1.2.0'},
      {'version': '1.2.0-beta'},
      {'buildNumber': 0},
      {'buildNumber': 65536},
      {'buildNumber': '20'},
    ]) {
      expect(
        () => UpdateRelease.fromJson({
          'schemaVersion': 1,
          'version': '1.2.0',
          'buildNumber': 20,
          'description': 'Исправления',
          ...override,
        }),
        throwsFormatException,
      );
    }
  });
}

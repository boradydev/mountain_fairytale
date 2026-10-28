import 'package:package_info_plus/package_info_plus.dart';

class ClientBuildInfo {
  final String version;
  final String build;

  ClientBuildInfo({required this.version, required this.build}) {
    parseVersion(version);
    final number = int.tryParse(build);
    if (number == null || number < 0 || number > 65535) {
      throw const FormatException('Некорректный номер сборки приложения.');
    }
  }

  static Future<ClientBuildInfo> load() async {
    final info = await PackageInfo.fromPlatform();
    return ClientBuildInfo(version: info.version, build: info.buildNumber);
  }

  static List<int> parseVersion(String value) {
    if (!RegExp(
      r'^(0|[1-9][0-9]{0,4})\.(0|[1-9][0-9]{0,4})\.(0|[1-9][0-9]{0,4})$',
    ).hasMatch(value)) {
      throw const FormatException('Некорректная версия приложения.');
    }
    final parts = value.split('.').map(int.parse).toList();
    if (parts.any((part) => part > 65535)) {
      throw const FormatException('Некорректная версия приложения.');
    }
    return parts;
  }

  bool supportsMinimum(String minimum) {
    final current = parseVersion(version);
    final required = parseVersion(minimum);
    for (var i = 0; i < 3; i++) {
      if (current[i] != required[i]) return current[i] > required[i];
    }
    return true;
  }
}

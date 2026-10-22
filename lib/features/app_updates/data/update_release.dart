class UpdateRelease {
  final String version;
  final int buildNumber;
  final String description;

  const UpdateRelease({
    required this.version,
    required this.buildNumber,
    required this.description,
  });

  factory UpdateRelease.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final build = json['buildNumber'];
    final description = json['description'];
    if (json['schemaVersion'] != 1 ||
        version is! String ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
        build is! int ||
        build < 1 ||
        build > 65535 ||
        description is! String ||
        description.length > 16000) {
      throw const FormatException('Некорректное описание обновления');
    }
    return UpdateRelease(
      version: version,
      buildNumber: build,
      description: description,
    );
  }

  bool isNewerThan(String installed) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$')
        .firstMatch(installed);
    if (match == null) return false;
    final current = [for (var i = 1; i <= 4; i++) int.parse(match[i] ?? '0')];
    final candidate = [...version.split('.').map(int.parse), buildNumber];
    for (var i = 0; i < 4; i++) {
      if (candidate[i] != current[i]) return candidate[i] > current[i];
    }
    return false;
  }
}

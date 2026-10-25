class MonitoringConfig {
  final String dsn;
  final String environment;

  const MonitoringConfig(this.dsn, this.environment);

  static MonitoringConfig? parse(String apiUrl, Map<String, dynamic> data) {
    if (data['enabled'] != true) return null;
    final key = data['publicKey'];
    final project = data['projectId'];
    final port = data['port'];
    if (key is! String ||
        !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(key) ||
        project is! String ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(project) ||
        port is! int ||
        port < 1 ||
        port > 65535) {
      return null;
    }
    final api = Uri.parse(apiUrl);
    if (!{'http', 'https'}.contains(api.scheme) || api.host.isEmpty) {
      return null;
    }
    return MonitoringConfig(
      Uri(
        scheme: api.scheme,
        userInfo: key,
        host: api.host,
        port: port,
        path: '/$project',
      ).toString(),
      data['environment'] is String
          ? data['environment'] as String
          : 'production',
    );
  }
}

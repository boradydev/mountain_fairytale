import 'package:flutter/widgets.dart';

/// Keeps the application's dependencies alive for one selected server.
/// Use the server URL as the key so changing servers replaces the whole scope.
class ServerApplicationScope extends StatefulWidget {
  final Widget Function() createApplication;

  const ServerApplicationScope({
    required super.key,
    required this.createApplication,
  });

  @override
  State<ServerApplicationScope> createState() => _ServerApplicationScopeState();
}

class _ServerApplicationScopeState extends State<ServerApplicationScope> {
  late final Widget _application;

  @override
  void initState() {
    super.initState();
    // Creating services in build can split authentication and API requests
    // between different instances when Flutter rebuilds this subtree.
    _application = widget.createApplication();
  }

  @override
  Widget build(BuildContext context) => _application;
}

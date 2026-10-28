import 'dart:io';

import 'package:mountain_fairytale/core/network/client_build_info.dart';

// Headless live tests have no installed Windows package metadata.
ClientBuildInfo liveClientBuild() {
  final manifest = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(manifest);
  if (match == null) throw const FormatException('Missing pubspec version');
  return ClientBuildInfo(version: match[1]!, build: match[2]!);
}

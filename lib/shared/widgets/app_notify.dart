import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/snack_bar_widget.dart';

/// The single entry point for transient application notifications.
class AppNotify {
  static _AppNotificationHostState? _host;

  static void show(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    _host?._show(message, isError: isError, isWarning: isWarning);
  }
}

/// Place in MaterialApp.builder to paint notifications above Navigator routes,
/// including modal barriers and nested dialogs.
class AppNotificationHost extends StatefulWidget {
  final Widget child;

  const AppNotificationHost({super.key, required this.child});

  @override
  State<AppNotificationHost> createState() => _AppNotificationHostState();
}

class _AppNotificationHostState extends State<AppNotificationHost> {
  Timer? _timer;
  ({String message, bool isError, bool isWarning})? _notification;

  @override
  void initState() {
    super.initState();
    AppNotify._host = this;
  }

  void _show(String message, {required bool isError, required bool isWarning}) {
    _timer?.cancel();
    setState(() {
      _notification = (
        message: message,
        isError: isError,
        isWarning: isWarning,
      );
    });
    // The newest notification replaces the previous one, without a backlog.
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notification = null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (identical(AppNotify._host, this)) AppNotify._host = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notification = _notification;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (notification != null)
          Positioned.fill(
            child: IgnorePointer(
              child: SafeArea(
                minimum: const EdgeInsets.all(16),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Semantics(
                      liveRegion: true,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: AppSnackBarContent(
                          message: notification.message,
                          isError: notification.isError,
                          isWarning: notification.isWarning,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

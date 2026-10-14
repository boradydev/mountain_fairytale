import 'package:flutter/material.dart';

/// Единое оформление заголовка и описания списков на дашборде.
class AppListSectionHeader extends StatelessWidget {
  final String title;
  final String description;
  final Widget? controls;
  final double? height;
  const AppListSectionHeader({
    super.key,
    required this.title,
    required this.description,
    this.controls,
    this.height,
  });

  static double _lineHeight(BuildContext context, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: 'А', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  static double preferredHeight(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _lineHeight(context, textTheme.titleMedium) +
        _lineHeight(context, textTheme.bodySmall) +
        72;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleHeight = _lineHeight(context, theme.textTheme.titleMedium);
    final descriptionHeight = _lineHeight(context, theme.textTheme.bodySmall);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: titleHeight,
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: descriptionHeight,
            child: Tooltip(
              message: description,
              child: Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: Align(
              alignment: Alignment.centerLeft,
              child: controls ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      height: height ?? preferredHeight(context),
      child: SingleChildScrollView(child: content),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mountain_fairytale/shared/widgets/app_date_range_dialog.dart';

Future<DateTimeRange?> showAppDateRangePicker(
  BuildContext context, {
  DateTimeRange? initialDateRange,
  required String helpText,
  int? maxRangeMonths,
  bool showReset = false,
}) => showDialog<DateTimeRange>(
  context: context,
  builder: (_) => AppDateRangeDialog(
    initialDateRange: initialDateRange,
    title: helpText,
    maxRangeMonths: maxRangeMonths,
    showReset: showReset,
  ),
);

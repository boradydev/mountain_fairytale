import 'package:flutter/material.dart';

Future<DateTimeRange?> showAppDateRangePicker(
  BuildContext context, {
  DateTimeRange? initialDateRange,
  required String helpText,
}) => showDateRangePicker(
  context: context,
  firstDate: DateTime(1900),
  lastDate: DateTime(2100, 12, 31),
  initialDateRange: initialDateRange,
  helpText: helpText,
  saveText: 'Применить',
  cancelText: 'Отмена',
  fieldStartLabelText: 'От',
  fieldEndLabelText: 'До',
);

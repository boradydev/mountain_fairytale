import 'package:flutter/material.dart';

/// Inclusive end of a calendar period; normalizes leap days across years.
DateTime lastDateOfRange(DateTime start, int months) =>
    DateTime(start.year, start.month + months, start.day - 1);

bool isDateRangeWithinMonths(DateTimeRange range, int months) =>
    !DateUtils.dateOnly(range.end).isBefore(DateUtils.dateOnly(range.start)) &&
    !DateUtils.dateOnly(range.end).isAfter(
      lastDateOfRange(DateUtils.dateOnly(range.start), months),
    );

extension DateTimeFormatting on DateTime {
  /// Проверяет, является ли дата сегодняшним днем
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Преобразует дату в строковый формат DD.MM.YYYY
  String toFormattedString() {
    final dayStr = day.toString().padLeft(2, '0');
    final monthStr = month.toString().padLeft(2, '0');
    return '$dayStr.$monthStr.$year';
  }
}

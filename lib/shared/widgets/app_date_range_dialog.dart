import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';
import 'package:intl/intl.dart';
import 'package:mountain_fairytale/shared/utils/date_range_limits.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';
import 'package:mountain_fairytale/shared/widgets/icon_button_widget.dart';

/// A draft date range shared by reports and filters. Only confirmation applies it.
class AppDateRangeDialog extends StatefulWidget {
  final String title;
  final DateTimeRange? initialDateRange;
  final DateTime? currentDate;
  final int? maxRangeMonths;
  final bool showReset;

  const AppDateRangeDialog({
    super.key,
    required this.title,
    this.initialDateRange,
    this.currentDate,
    this.maxRangeMonths,
    this.showReset = false,
  });

  @override
  State<AppDateRangeDialog> createState() => _AppDateRangeDialogState();
}

class _AppDateRangeDialogState extends State<AppDateRangeDialog> {
  static final _first = DateTime(1900);
  static final _last = DateTime(2100, 12, 31);
  final _form = GlobalKey<FormState>();
  final _format = DateFormat('dd.MM.yyyy');
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final DateTime _today;
  DateTime? _start;
  DateTime? _end;
  late DateTime _month;
  bool _selectingEnd = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _today = DateUtils.dateOnly(widget.currentDate ?? DateTime.now());
    _start = widget.initialDateRange?.start;
    _end = widget.initialDateRange?.end;
    _from = TextEditingController(
      text: _start == null ? '' : _format.format(_start!),
    );
    _to = TextEditingController(
      text: _end == null ? '' : _format.format(_end!),
    );
    final initial = _start ?? _today;
    _month = DateTime(initial.year.clamp(1900, 2100), initial.month);
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  DateTime? _parse(String text) {
    final value = text.trim();
    if (!RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(value)) return null;
    return _format.tryParseStrict(value);
  }

  bool _inBounds(DateTime value) =>
      !value.isBefore(_first) && !value.isAfter(_last);

  String? _validate(String? text, {required bool end}) {
    final date = _parse(text ?? '');
    if (date == null) return 'Введите дату дд.мм.гггг';
    if (!_inBounds(date)) return 'Дата должна быть в пределах 1900–2100';
    final start = _parse(_from.text);
    if (end && start != null && date.isBefore(start)) {
      return 'Окончание раньше начала';
    }
    if (end &&
        start != null &&
        widget.maxRangeMonths != null &&
        date.isAfter(lastDateOfRange(start, widget.maxRangeMonths!))) {
      return 'Период не может превышать ${widget.maxRangeMonths} месяцев';
    }
    return null;
  }

  void _typed({required bool end}) {
    setState(() {
      _start = _parse(_from.text);
      _end = _parse(_to.text);
      _selectingEnd = false;
      final date = end ? _end : _start;
      if (date != null && _inBounds(date)) {
        _month = DateTime(date.year, date.month);
      }
    });
  }

  void _setDates(DateTime start, DateTime? end, {required bool selectingEnd}) {
    setState(() {
      _start = start;
      _end = end;
      _from.text = _format.format(start);
      _to.text = end == null ? '' : _format.format(end);
      _selectingEnd = selectingEnd;
    });
    if (_submitted) _form.currentState?.validate();
  }

  void _daySelected(DateTime day) {
    FocusScope.of(context).unfocus();
    if (_selectingEnd && _start != null) {
      _setDates(
        day.isBefore(_start!) ? day : _start!,
        day.isBefore(_start!) ? _start : day,
        selectingEnd: false,
      );
    } else {
      _setDates(day, null, selectingEnd: true);
    }
  }

  void _preset(DateTime start, DateTime end) {
    FocusScope.of(context).unfocus();
    _setDates(start, end, selectingEnd: false);
    setState(() => _month = DateTime(start.year, start.month));
  }

  void _confirm() {
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    Navigator.of(context)
        .pop(DateTimeRange(start: _parse(_from.text)!, end: _parse(_to.text)!));
  }

  Widget _dateField({required bool end}) => TextFormField(
    key: ValueKey(end ? 'period-end' : 'period-start'),
    controller: end ? _to : _from,
    keyboardType: TextInputType.datetime,
    textInputAction: end ? TextInputAction.done : TextInputAction.next,
    inputFormatters: [LengthLimitingTextInputFormatter(10)],
    decoration: InputDecoration(
      labelText: end ? 'Дата окончания' : 'Дата начала',
      hintText: 'дд.мм.гггг',
      border: const OutlineInputBorder(),
      errorMaxLines: 2,
    ),
    autovalidateMode: _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled,
    validator: (text) => _validate(text, end: end),
    onChanged: (_) => _typed(end: end),
    onFieldSubmitted: end ? (_) => _confirm() : null,
  );

  @override
  Widget build(BuildContext context) => BaseFormDialog(
    title: widget.title,
    submitButtonText: 'Подтвердить',
    onSubmit: _confirm,
    leadingAction: widget.showReset
        ? AppSecondaryButton(
            text: 'Сбросить',
            onPressed: () => _preset(
              DateTime(_today.year, _today.month, _today.day - 29),
              _today,
            ),
          )
        : null,
    formKey: _form,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 340) {
            return Column(
              children: [
                _dateField(end: false),
                const SizedBox(height: 16),
                _dateField(end: true),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _dateField(end: false)),
              const SizedBox(width: 12),
              Expanded(child: _dateField(end: true)),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            label: const Text('Этот месяц'),
            onPressed: () =>
                _preset(DateTime(_today.year, _today.month), _today),
          ),
          ActionChip(
            label: const Text('Прошлый месяц'),
            onPressed: () => _preset(
              DateTime(_today.year, _today.month - 1),
              DateTime(_today.year, _today.month, 0),
            ),
          ),
          ActionChip(
            label: const Text('Этот год'),
            onPressed: () => _preset(DateTime(_today.year), _today),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _calendar(),
    ],
  );

  Widget _calendar() {
    final locale = Localizations.localeOf(context).toString();
    final localizations = MaterialLocalizations.of(context);
    final weekStart = localizations.firstDayOfWeekIndex;
    final offset = (_month.weekday % 7 - weekStart + 7) % 7;
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: AppDropdown<int>(
                key: ValueKey('month-${_month.month}'),
                label: 'Месяц',
                items: List.generate(12, (i) => i + 1),
                value: _month.month,
                itemLabelBuilder: (month) =>
                    DateFormat.MMMM(locale).format(DateTime(2000, month)),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _month = DateTime(_month.year, value));
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppDropdown<int>(
                key: ValueKey('year-${_month.year}'),
                label: 'Год',
                items: List.generate(201, (i) => 1900 + i),
                value: _month.year,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _month = DateTime(value, _month.month));
                  }
                },
              ),
            ),
          ],
        ),
        Row(
          children: [
            AppIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Предыдущий месяц',
              onPressed: _month.year == 1900 && _month.month == 1
                  ? null
                  : () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    ),
            ),
            Expanded(
              child: Text(
                _selectingEnd
                    ? 'Выберите окончание периода'
                    : 'Выберите начало периода',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            AppIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Следующий месяц',
              onPressed: _month.year == 2100 && _month.month == 12
                  ? null
                  : () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    ),
            ),
          ],
        ),
        Row(
          children: List.generate(
            7,
            (i) => Expanded(
              child: Center(
                child: Text(
                  localizations.narrowWeekdays[(weekStart + i) % 7],
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (var week = 0; week < 6; week++)
          Row(
            children: List.generate(7, (column) {
              final day = week * 7 + column - offset + 1;
              return Expanded(
                child: day < 1 || day > days
                    ? const SizedBox(height: 36)
                    : _calendarDay(DateTime(_month.year, _month.month, day)),
              );
            }),
          ),
      ],
    );
  }

  Widget _calendarDay(DateTime day) {
    final colors = Theme.of(context).colorScheme;
    final validRange =
        _start != null && _end != null && !_end!.isBefore(_start!);
    final boundary =
        DateUtils.isSameDay(day, _start) ||
        validRange && DateUtils.isSameDay(day, _end);
    final inside = validRange && !day.isBefore(_start!) && !day.isAfter(_end!);
    return Semantics(
      label: DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString())
          .format(day),
      selected: boundary || inside,
      button: true,
      child: Material(
        color: boundary
            ? colors.primary
            : inside
            ? colors.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(boundary ? 18 : 4),
        child: InkWell(
          key: ValueKey('period-day-${DateFormat('yyyy-MM-dd').format(day)}'),
          onTap: () => _daySelected(day),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: DateUtils.isSameDay(day, _today) && !boundary
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary),
                  )
                : null,
            child: ExcludeSemantics(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: boundary
                      ? colors.onPrimary
                      : inside
                      ? colors.onPrimaryContainer
                      : colors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

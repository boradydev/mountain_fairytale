import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/widgets/text_button_widget.dart';

class MonthPickerDialog extends StatefulWidget {
  final DateTime initialMonth;
  const MonthPickerDialog({super.key, required this.initialMonth});

  @override
  State<MonthPickerDialog> createState() => MonthPickerDialogState();
}

class MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _year;
  late int _month;

  static const _months = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year;
    _month = widget.initialMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Выбор месяца'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_year',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 44,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final month = index + 1;
                final selected = month == _month;
                return OutlinedButton(
                  onPressed: () => setState(() => _month = month),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  child: Text(_months[index]),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        AppSecondaryButton(
          text: 'Отмена',
          onPressed: () => Navigator.pop(context),
        ),
        AppPrimaryButton(
          text: 'Выбрать',
          onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
        ),
      ],
    );
  }
}

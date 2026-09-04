import 'package:flutter/material.dart';
import 'package:mountain_fairytale/presentation/widgets/base_card_widget.dart';

class AddActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double? height; // Добавили опциональный параметр высоты

  const AddActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.height, // Передаем в конструктор
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Выносим содержимое кнопки
    Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          // mainAxisSize: MainAxisSize.min сожмет колонку, если высота динамическая.
          // Если задана фиксированная высота, Column займет всё доступное место,
          // а MainAxisAlignment.center удержит элементы ровно по центру.
          mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    // Если высота передана, ограничиваем контент по высоте
    if (height != null) {
      content = SizedBox(
        height: height,
        child: content,
      );
    }

    return AppBaseCard(
      onTap: onTap,
      child: content,
    );
  }
}

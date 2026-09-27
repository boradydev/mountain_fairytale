import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/presentation/providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select((ThemeProvider p) => p.isDarkMode);

    return IconButton(
      tooltip: isDarkMode ? 'Светлая тема' : 'Тёмная тема',
      icon: Icon(
        isDarkMode ? Icons.light_mode : Icons.dark_mode,
      ),
      onPressed: () {
        context.read<ThemeProvider>().toggleTheme();
      },
    );
  }
}

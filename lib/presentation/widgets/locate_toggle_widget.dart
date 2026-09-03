import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mountain_fairytale/presentation/providers/locale_provider.dart';

class LocaleToggleButton extends StatelessWidget {
  const LocaleToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = context.select(
      (LocaleProvider p) => p.locale.languageCode,
    );

    return TextButton(
      onPressed: () => context.read<LocaleProvider>().toggleLocale(),
      child: Text(
        langCode.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

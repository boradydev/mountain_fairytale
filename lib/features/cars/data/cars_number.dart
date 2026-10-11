const _latinToCyrillic = <String, String>{
  'A': 'А',
  'B': 'В',
  'E': 'Е',
  'K': 'К',
  'M': 'М',
  'H': 'Н',
  'O': 'О',
  'P': 'Р',
  'C': 'С',
  'T': 'Т',
  'Y': 'У',
  'X': 'Х',
};

final _carNumberPattern = RegExp(
  r'^[АВЕКМНОРСТУХ][0-9]{3}[АВЕКМНОРСТУХ]{2}[0-9]{2,3}$',
);

String canonicalCarNumber(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  return compact
      .split('')
      .map((character) => _latinToCyrillic[character] ?? character)
      .join();
}

String formatCarNumber(String value) {
  final canonical = canonicalCarNumber(value);
  if (canonical.length <= 6) return canonical;
  return '${canonical.substring(0, 6)} ${canonical.substring(6)}';
}

bool isValidCarNumber(String value) =>
    _carNumberPattern.hasMatch(canonicalCarNumber(value));

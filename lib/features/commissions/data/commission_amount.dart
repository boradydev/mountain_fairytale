/// Keeps exact decimal API values and rounds only at the display boundary.
class CommissionAmount {
  final String exact;
  const CommissionAmount(this.exact);
  static const zero = CommissionAmount('0');

  factory CommissionAmount.fromJson(Object value) =>
      CommissionAmount(value.toString());

  BigInt get cents {
    final match = RegExp(
      r'^([+-]?)(\d+)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$',
    ).firstMatch(exact);
    if (match == null) throw FormatException('Invalid decimal amount', exact);
    final fraction = match.group(3) ?? '';
    final digits = BigInt.parse('${match.group(2)}$fraction');
    final scale = fraction.length - int.parse(match.group(4) ?? '0') - 2;
    final BigInt rounded;
    if (scale <= 0) {
      rounded = digits * BigInt.from(10).pow(-scale);
    } else {
      final divisor = BigInt.from(10).pow(scale);
      rounded = (digits + divisor ~/ BigInt.two) ~/ divisor;
    }
    return match.group(1) == '-' ? -rounded : rounded;
  }

  String get formatted => formatCommissionCents(cents);
}

String formatCommissionCents(BigInt cents) {
  final value = cents.abs();
  return '${cents.isNegative ? '-' : ''}${value ~/ BigInt.from(100)}.'
      '${(value % BigInt.from(100)).toString().padLeft(2, '0')} ₽';
}

/// Decimal HALF_UP rounding, before any binary floating point multiplication.
int lineAmountCents(int quantity, double price) {
  if (quantity <= 0 || !price.isFinite || price < 0) {
    throw ArgumentError('Invalid quantity or price.');
  }
  final parts = price.toString().toLowerCase().split('e');
  final exponent = parts.length == 2 ? int.parse(parts[1]) : 0;
  final decimal = parts[0].split('.');
  final digits = BigInt.parse(decimal.join());
  final scale = (decimal.length == 2 ? decimal[1].length : 0) - exponent;
  final numerator = digits * BigInt.from(quantity) * BigInt.from(100);
  if (scale <= 0) {
    return (numerator * BigInt.from(10).pow(-scale)).toInt();
  }
  final denominator = BigInt.from(10).pow(scale);
  return ((numerator + denominator ~/ BigInt.two) ~/ denominator).toInt();
}

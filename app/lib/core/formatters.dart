// Currency, date, and quantity formatters for Mâm.

String formatVnd(int amount, {bool withSuffix = true}) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final posFromRight = digits.length - i;
    if (i > 0 && posFromRight % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  final prefix = negative ? '-' : '';
  final suffix = withSuffix ? 'đ' : '';
  return '$prefix${buffer.toString()}$suffix';
}

String formatSignedVnd(int amount, {bool withSuffix = true}) {
  if (amount > 0) return '+${formatVnd(amount, withSuffix: withSuffix)}';
  return formatVnd(amount, withSuffix: withSuffix);
}

int parseVndInput(String raw) {
  final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return 0;
  return int.tryParse(digitsOnly) ?? 0;
}

String formatDateVn(DateTime date, {bool includeYear = false}) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  if (!includeYear) return '$d/$m';
  return '$d/$m/${date.year}';
}

String formatQty(double qty) {
  if (qty == qty.roundToDouble()) {
    return qty.round().toString();
  }
  return qty.toStringAsFixed(1);
}

String defaultMealTitle({DateTime? now, bool isVi = false}) {
  final dt = now ?? DateTime.now();
  final h = dt.hour;
  final label = isVi
      ? switch (h) {
          >= 5 && <= 10 => 'Ăn sáng',
          >= 11 && <= 14 => 'Ăn trưa',
          >= 15 && <= 17 => 'Ăn chiều',
          >= 18 && <= 21 => 'Ăn tối',
          _ => 'Ăn khuya',
        }
      : switch (h) {
          >= 5 && <= 10 => 'Breakfast',
          >= 11 && <= 14 => 'Lunch',
          >= 15 && <= 17 => 'Afternoon tea',
          >= 18 && <= 21 => 'Dinner',
          _ => 'Late-night meal',
        };
  return '$label ${formatDateVn(dt)}';
}

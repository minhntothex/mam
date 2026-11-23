import 'amount_input_formatter.dart';
import 'currency.dart';

// Currency, date, and quantity formatters for Mâm.

String formatMoney(
  int amount, {
  CurrencySpec currency = CurrencyRegistry.vnd,
  AmountInputFormat format = AmountInputFormat.auto,
  bool withSymbol = true,
}) {
  final negative = amount < 0;
  final absVal = amount.abs();
  final effective = currency.resolveInputFormat(format);

  String body;
  if (currency.decimalDigits > 0 || effective == AmountInputFormat.usdDecimal) {
    final decimals = currency.decimalDigits > 0 ? currency.decimalDigits : 2;
    if (absVal == 0) {
      body = '0.${'0' * decimals}';
    } else {
      body = formatAtmDecimal(
        absVal.toString(),
        decimalDigits: decimals,
        thousandsSep: currency.thousandsSep,
        decimalSep: currency.decimalSep,
      );
    }
  } else if (effective == AmountInputFormat.plain) {
    body = absVal.toString();
  } else {
    body = formatGroupedInteger(
      absVal.toString(),
      separator: currency.thousandsSep,
    );
  }

  final sign = negative ? '-' : '';
  if (!withSymbol) return '$sign$body';
  return currency.symbolBefore
      ? '$sign${currency.symbol}$body'
      : '$sign$body${currency.symbol}';
}

String formatSignedMoney(
  int amount, {
  CurrencySpec currency = CurrencyRegistry.vnd,
  AmountInputFormat format = AmountInputFormat.auto,
  bool withSymbol = true,
}) {
  if (amount > 0) {
    return '+${formatMoney(amount, currency: currency, format: format, withSymbol: withSymbol)}';
  }
  return formatMoney(
    amount,
    currency: currency,
    format: format,
    withSymbol: withSymbol,
  );
}

String formatVnd(int amount, {bool withSuffix = true}) => formatMoney(
      amount,
      currency: CurrencyRegistry.vnd,
      withSymbol: withSuffix,
    );

String formatSignedVnd(int amount, {bool withSuffix = true}) =>
    formatSignedMoney(
      amount,
      currency: CurrencyRegistry.vnd,
      withSymbol: withSuffix,
    );

int parseVndInput(String raw) => parseAmountInput(raw);

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

import 'package:flutter/services.dart';

import 'currency.dart';

// Strict numeric-only live amount formatter supporting scalable presets:
// - `dotThousands` (VND default): 1000 -> 1.000, 312592 -> 312.592, 5923892 -> 5.923.892
// - `usdDecimal` (ATM/POS shift): 1 -> 0.01, 100 -> 1.00, 312592 -> 3,125.92
// - `plain`: raw digits only (1000 -> 1000)

const int _kMaxAmountDigits = 12;

/// Formats a raw digit string into grouped integer text (`1000` -> `1.000`).
String formatGroupedInteger(String digits, {String separator = '.'}) {
  final cleaned = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (cleaned.isEmpty) return '';
  final buf = StringBuffer();
  for (var i = 0; i < cleaned.length; i++) {
    final fromRight = cleaned.length - i;
    if (i > 0 && fromRight % 3 == 0) {
      buf.write(separator);
    }
    buf.write(cleaned[i]);
  }
  return buf.toString();
}

/// Formats an ATM/POS digit stream into fixed-decimal text (`1` -> `0.01`,
/// `100` -> `1.00`, `312592` -> `3,125.92`).
String formatAtmDecimal(
  String rawDigits, {
  int decimalDigits = 2,
  String thousandsSep = ',',
  String decimalSep = '.',
}) {
  final stripped = rawDigits.replaceFirst(RegExp(r'^0+'), '');
  if (stripped.isEmpty) return '';
  final padded = stripped.padLeft(decimalDigits + 1, '0');
  final intPart = padded.substring(0, padded.length - decimalDigits);
  final fracPart = padded.substring(padded.length - decimalDigits);
  final groupedInt = formatGroupedInteger(intPart, separator: thousandsSep);
  return '${groupedInt.isEmpty ? '0' : groupedInt}$decimalSep$fracPart';
}

/// Formats a stored minor-unit integer for pre-populating a `TextField`.
String formatAmountForInput(
  int minorAmount, {
  CurrencySpec currency = CurrencyRegistry.vnd,
  AmountInputFormat format = AmountInputFormat.auto,
}) {
  if (minorAmount <= 0) return '';
  final effective = currency.resolveInputFormat(format);
  final digits = minorAmount.toString();
  return switch (effective) {
    AmountInputFormat.dotThousands => formatGroupedInteger(digits, separator: '.'),
    AmountInputFormat.usdDecimal => formatAtmDecimal(
        digits,
        decimalDigits: currency.decimalDigits > 0 ? currency.decimalDigits : 2,
        thousandsSep: ',',
        decimalSep: '.',
      ),
    AmountInputFormat.plain => digits,
    AmountInputFormat.auto => formatGroupedInteger(digits, separator: '.'),
  };
}

/// Parses formatted numeric text back into minor-unit integer.
int parseAmountInput(String raw) {
  final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return 0;
  final capped = digitsOnly.length > _kMaxAmountDigits
      ? digitsOnly.substring(0, _kMaxAmountDigits)
      : digitsOnly;
  return int.tryParse(capped) ?? 0;
}

class AmountTextInputFormatter extends TextInputFormatter {
  const AmountTextInputFormatter({
    required this.currency,
    this.format = AmountInputFormat.auto,
  });

  final CurrencySpec currency;
  final AmountInputFormat format;

  AmountInputFormat get effectiveFormat => currency.resolveInputFormat(format);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final cappedDigits = digitsOnly.length > _kMaxAmountDigits
        ? digitsOnly.substring(0, _kMaxAmountDigits)
        : digitsOnly;

    final effective = effectiveFormat;
    if (effective == AmountInputFormat.usdDecimal) {
      final formatted = formatAtmDecimal(
        cappedDigits,
        decimalDigits: currency.decimalDigits > 0 ? currency.decimalDigits : 2,
        thousandsSep: ',',
        decimalSep: '.',
      );
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    // Count how many digits appeared before the user's cursor to preserve caret
    // accurately when inserting or deleting digits in the middle of a number.
    final rawCursor = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCursor = newValue.text
        .substring(0, rawCursor)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    final normalizedDigits = cappedDigits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final leadingZerosStripped = cappedDigits.length - normalizedDigits.length;
    final targetDigitsBefore =
        (digitsBeforeCursor - leadingZerosStripped).clamp(0, normalizedDigits.length);

    final formatted = effective == AmountInputFormat.plain
        ? normalizedDigits
        : formatGroupedInteger(normalizedDigits, separator: '.');

    var newOffset = 0;
    var seenDigits = 0;
    while (newOffset < formatted.length && seenDigits < targetDigitsBefore) {
      final code = formatted.codeUnitAt(newOffset);
      if (code >= 48 && code <= 57) {
        seenDigits++;
      }
      newOffset++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

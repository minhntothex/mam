// Scalable currency & amount input format registry for Mâm.
//
// Amounts are stored internally as exact `int` minor units:
// - VND (`decimalDigits = 0`): 1000 = 1.000đ
// - USD (`decimalDigits = 2`): 100  = $1.00 (100 cents)
// Adding new currencies (EUR, JPY, SGD, KRW, ...) only requires adding a
// `CurrencySpec` entry to `CurrencyRegistry.all`.

enum AmountInputFormat {
  auto('auto'),
  dotThousands('dot_thousands'),
  usdDecimal('usd_decimal'),
  plain('plain');

  const AmountInputFormat(this.value);
  final String value;

  static AmountInputFormat fromValue(String? raw) {
    return AmountInputFormat.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => AmountInputFormat.auto,
    );
  }
}

final class CurrencySpec {
  const CurrencySpec({
    required this.code,
    required this.symbol,
    required this.label,
    required this.decimalDigits,
    required this.symbolBefore,
    required this.thousandsSep,
    required this.decimalSep,
    required this.roundingStep,
    required this.roundingStepLabelEn,
    required this.roundingStepLabelVi,
    required this.quickPresets,
    required this.sampleHint,
    required this.supportsVietQr,
  });

  final String code;
  final String symbol;
  final String label;
  final int decimalDigits;
  final bool symbolBefore;
  final String thousandsSep;
  final String decimalSep;
  final int roundingStep;
  final String roundingStepLabelEn;
  final String roundingStepLabelVi;
  final List<int> quickPresets;
  final String sampleHint;
  final bool supportsVietQr;

  AmountInputFormat resolveInputFormat(AmountInputFormat preference) {
    if (preference != AmountInputFormat.auto) return preference;
    return decimalDigits > 0
        ? AmountInputFormat.usdDecimal
        : AmountInputFormat.dotThousands;
  }
}

abstract final class CurrencyRegistry {
  static const CurrencySpec vnd = CurrencySpec(
    code: 'VND',
    symbol: 'đ',
    label: 'đ / VNĐ',
    decimalDigits: 0,
    symbolBefore: false,
    thousandsSep: '.',
    decimalSep: ',',
    roundingStep: 1000,
    roundingStepLabelEn: '1,000đ',
    roundingStepLabelVi: '1.000đ',
    quickPresets: [100000, 200000, 300000, 500000, 1000000],
    sampleHint: '300.000',
    supportsVietQr: true,
  );

  static const CurrencySpec usd = CurrencySpec(
    code: 'USD',
    symbol: r'$',
    label: r'$ / USD',
    decimalDigits: 2,
    symbolBefore: true,
    thousandsSep: ',',
    decimalSep: '.',
    roundingStep: 100, // $1.00 in cents
    roundingStepLabelEn: r'$1',
    roundingStepLabelVi: r'$1',
    quickPresets: [1000, 2000, 5000, 10000, 20000], // $10 .. $200
    sampleHint: '30.00',
    supportsVietQr: false,
  );

  /// Ordered list displayed in Settings. Append new currencies here to scale.
  static const List<CurrencySpec> all = [vnd, usd];

  static CurrencySpec byCode(String? code) {
    final normalized = code?.trim().toUpperCase();
    for (final spec in all) {
      if (spec.code == normalized) return spec;
    }
    return vnd;
  }
}

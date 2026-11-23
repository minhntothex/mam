import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mam/core/amount_input_formatter.dart';
import 'package:mam/core/calculator.dart';
import 'package:mam/core/currency.dart';
import 'package:mam/core/formatters.dart';
import 'package:mam/models/bill_models.dart';

TextEditingValue _apply(
  AmountTextInputFormatter formatter,
  String oldText,
  String newText, {
  int? cursor,
}) {
  return formatter.formatEditUpdate(
    TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldText.length),
    ),
    TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor ?? newText.length),
    ),
  );
}

void main() {
  test('VND dotThousands formatter blocks non-digits and groups 1.000 / 312.592 / 5.923.892', () {
    const f = AmountTextInputFormatter(
      currency: CurrencyRegistry.vnd,
      format: AmountInputFormat.auto,
    );

    expect(_apply(f, '', 'abc').text, '');
    expect(_apply(f, '', '1000').text, '1.000');
    expect(_apply(f, '', '312592').text, '312.592');
    expect(_apply(f, '', '5923892').text, '5.923.892');
    expect(_apply(f, '1.000', '1.000abc').text, '1.000');
    expect(parseAmountInput('5.923.892'), 5923892);
  });

  test('VND dotThousands preserves cursor position when editing middle digits', () {
    const f = AmountTextInputFormatter(
      currency: CurrencyRegistry.vnd,
      format: AmountInputFormat.dotThousands,
    );

    // Inserting '5' right after '1.' in '1.000' -> '15.000', cursor after '5' (index 2).
    final res = _apply(f, '1.000', '15.000', cursor: 2);
    expect(res.text, '15.000');
    expect(res.selection.baseOffset, 2);
  });

  test('USD ATM/POS formatter shifts right-to-left: 1 -> 0.01, 100 -> 1.00, 312592 -> 3,125.92', () {
    const f = AmountTextInputFormatter(
      currency: CurrencyRegistry.usd,
      format: AmountInputFormat.auto,
    );

    expect(_apply(f, '', 'abc').text, '');
    expect(_apply(f, '', '1').text, '0.01');
    expect(_apply(f, '0.01', '0.010').text, '0.10');
    expect(_apply(f, '0.10', '0.100').text, '1.00');
    expect(_apply(f, '', '312592').text, '3,125.92');
    expect(_apply(f, '', '5923892').text, '59,238.92');
    expect(parseAmountInput('3,125.92'), 312592);
    expect(formatMoney(312592, currency: CurrencyRegistry.usd), r'$3,125.92');
    expect(formatMoney(100, currency: CurrencyRegistry.usd), r'$1.00');
  });

  test('Plain formatter keeps digits only without separators', () {
    const f = AmountTextInputFormatter(
      currency: CurrencyRegistry.vnd,
      format: AmountInputFormat.plain,
    );

    expect(_apply(f, '', 'abc5923892!').text, '5923892');
  });

  test(r'BillCalculator uses currency roundingStep ($1 for USD vs 1,000đ for VND)', () {
    final usdPayload = BillPayload(
      currencyCode: 'USD',
      roundingMode: RoundingMode.ceil1000,
      participants: const [
        Participant(id: 'a', name: 'Me', isHost: true, paid: true),
        Participant(id: 'b', name: 'Alex'),
        Participant(id: 'c', name: 'Sam'),
      ],
      items: const [
        BillItem(
          id: 'i1',
          name: 'Pizza',
          lineTotal: 1000, // $10.00 in cents -> $3.333 each -> rounds up to $4.00 (400 cents)
          shares: {'a': 1, 'b': 1, 'c': 1},
        ),
      ],
    );

    final res = BillCalculator.calculate(usdPayload);
    expect(res.breakdowns.every((b) => b.finalAmount == 400), isTrue);
    expect(res.roundingDelta, 200); // +$2.00
  });
}

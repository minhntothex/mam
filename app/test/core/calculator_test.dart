import 'package:flutter_test/flutter_test.dart';
import 'package:mam/core/calculator.dart';
import 'package:mam/models/bill_models.dart';

void main() {
  group('BillCalculator', () {
    test('allocates VAT and bill discount pro-rata', () {
      // A eats 200k, B eats 100k -> subtotal 300k
      // VAT 30k (+10%), bill discount 30k (-10%) -> net pro-rata = 0 -> A=200k, B=100k
      // With VAT 30k and bill discount 15k -> net pro-rata = +15k (+5%) -> A=210k, B=105k
      const payload = BillPayload(
        participants: [
          Participant(id: 'a', name: 'An', isHost: true, paid: true),
          Participant(id: 'b', name: 'Bình'),
        ],
        items: [
          BillItem(id: 'i1', name: 'Bò nướng', lineTotal: 200000, shares: {'a': 1}),
          BillItem(id: 'i2', name: 'Mì xào', lineTotal: 100000, shares: {'b': 1}),
        ],
        adjustments: BillAdjustments(
          taxAmount: 30000,
          billDiscountAmount: 15000,
        ),
        roundingMode: RoundingMode.none,
      );

      final result = BillCalculator.calculate(payload);
      expect(result.computedGrandTotal, 315000);
      expect(result.breakdownFor('a')!.finalAmount, 210000);
      expect(result.breakdownFor('b')!.finalAmount, 105000);
      expect(result.roundingDelta, 0);
      expect(result.hasUnassignedItems, isFalse);
    });

    test('separates item-level discount from bill-level discount', () {
      const payload = BillPayload(
        participants: [
          Participant(id: 'a', name: 'An'),
          Participant(id: 'b', name: 'Bình'),
        ],
        items: [
          BillItem(
            id: 'i1',
            name: 'Cơm tấm (voucher riêng)',
            lineTotal: 100000,
            itemDiscount: 20000,
            shares: {'a': 1},
          ),
          BillItem(id: 'i2', name: 'Phở bò', lineTotal: 80000, shares: {'b': 1}),
        ],
        roundingMode: RoundingMode.none,
      );

      final result = BillCalculator.calculate(payload);
      expect(result.breakdownFor('a')!.finalAmount, 80000);
      expect(result.breakdownFor('b')!.finalAmount, 80000);
      expect(result.computedGrandTotal, 160000);
    });

    test('supports flat shipping vs pro-rata shipping', () {
      const baseItems = [
        BillItem(id: 'i1', name: 'Món đắt', lineTotal: 300000, shares: {'a': 1}),
        BillItem(id: 'i2', name: 'Món rẻ', lineTotal: 100000, shares: {'b': 1}),
      ];
      const people = [
        Participant(id: 'a', name: 'An'),
        Participant(id: 'b', name: 'Bình'),
      ];

      final flatRes = BillCalculator.calculate(
        const BillPayload(
          participants: people,
          items: baseItems,
          adjustments: BillAdjustments(
            shippingAmount: 20000,
            shippingMode: ShippingSplitMode.flat,
          ),
          roundingMode: RoundingMode.none,
        ),
      );
      expect(flatRes.breakdownFor('a')!.finalAmount, 310000);
      expect(flatRes.breakdownFor('b')!.finalAmount, 110000);

      final proRataRes = BillCalculator.calculate(
        const BillPayload(
          participants: people,
          items: baseItems,
          adjustments: BillAdjustments(
            shippingAmount: 20000,
            shippingMode: ShippingSplitMode.proRata,
          ),
          roundingMode: RoundingMode.none,
        ),
      );
      expect(proRataRes.breakdownFor('a')!.finalAmount, 315000);
      expect(proRataRes.breakdownFor('b')!.finalAmount, 105000);
    });

    test('splits weighted quantities (e.g. 3 drinks: A=2, B=1)', () {
      const payload = BillPayload(
        participants: [
          Participant(id: 'a', name: 'An'),
          Participant(id: 'b', name: 'Bình'),
        ],
        items: [
          BillItem(
            id: 'i1',
            name: 'Trà sữa',
            quantity: 3,
            lineTotal: 150000,
            shares: {'a': 2, 'b': 1},
          ),
        ],
        roundingMode: RoundingMode.none,
      );

      final res = BillCalculator.calculate(payload);
      expect(res.breakdownFor('a')!.finalAmount, 100000);
      expect(res.breakdownFor('b')!.finalAmount, 50000);
    });

    test('detects unassigned items and guards division by zero', () {
      const payload = BillPayload(
        participants: [
          Participant(id: 'a', name: 'An'),
        ],
        items: [
          BillItem(id: 'i1', name: 'Khăn lạnh', lineTotal: 12000),
        ],
        adjustments: BillAdjustments(taxAmount: 1000),
      );

      final res = BillCalculator.calculate(payload);
      expect(res.hasUnassignedItems, isTrue);
      expect(res.unassignedTotal, 12000);
      expect(res.breakdownFor('a')!.finalAmount, 0);
      expect(res.computedGrandTotal, 13000);
    });

    test('computes rounding modes and transparent roundingDelta (100k / 3)', () {
      const base = BillPayload(
        participants: [
          Participant(id: 'a', name: 'An'),
          Participant(id: 'b', name: 'Bình'),
          Participant(id: 'c', name: 'Chi'),
        ],
        items: [
          BillItem(
            id: 'i1',
            name: 'Lẩu',
            lineTotal: 100000,
            shares: {'a': 1, 'b': 1, 'c': 1},
          ),
        ],
      );

      final exact = BillCalculator.calculate(
        base.copyWith(roundingMode: RoundingMode.none),
      );
      expect(exact.breakdownFor('a')!.finalAmount, 33333);
      expect(exact.sumFinalAmounts, 99999);
      expect(exact.roundingDelta, -1);

      final ceil = BillCalculator.calculate(
        base.copyWith(roundingMode: RoundingMode.ceil1000),
      );
      expect(ceil.breakdownFor('a')!.finalAmount, 34000);
      expect(ceil.sumFinalAmounts, 102000);
      expect(ceil.roundingDelta, 2000);

      // Legacy persisted `nearest_1000` maps safely to `ceil1000`.
      expect(RoundingMode.fromValue('nearest_1000'), RoundingMode.ceil1000);
    });

    test('reports OCR grand total reconciliation difference', () {
      const payload = BillPayload(
        participants: [Participant(id: 'a', name: 'An')],
        items: [
          BillItem(id: 'i1', name: 'Phở', lineTotal: 60000, shares: {'a': 1}),
        ],
        adjustments: BillAdjustments(ocrGrandTotal: 65000),
      );

      final res = BillCalculator.calculate(payload);
      expect(res.isOcrMatched, isFalse);
      expect(res.ocrDifference, -5000);
    });

    test('marks payment status settled when all non-host participants paid', () {
      const pending = BillPayload(
        participants: [
          Participant(id: 'me', name: 'Tôi', isHost: true, paid: false),
          Participant(id: 'b', name: 'Bình', paid: false),
        ],
        items: [
          BillItem(id: 'i1', name: 'Phở', lineTotal: 50000, shares: {'b': 1}),
        ],
      );
      expect(BillCalculator.computePaymentStatus(pending), PaymentStatus.pending);

      const settled = BillPayload(
        participants: [
          Participant(id: 'me', name: 'Tôi', isHost: true, paid: false),
          Participant(id: 'b', name: 'Bình', paid: true),
        ],
        items: [
          BillItem(id: 'i1', name: 'Phở', lineTotal: 50000, shares: {'b': 1}),
        ],
      );
      expect(BillCalculator.computePaymentStatus(settled), PaymentStatus.settled);
    });

    test('auto-marks zero-debt members paid and reverts auto-paid when edited to owe > 0', () {
      final manualPaidAt = DateTime.utc(2026, 11, 23, 6, 0);
      final payload = BillPayload(
        participants: [
          const Participant(id: 'me', name: 'Tôi', isHost: true, paid: true),
          Participant(id: 'a', name: 'An', paid: true, paidAt: manualPaidAt),
          const Participant(id: 'z', name: 'Zero', paid: false),
        ],
        items: const [
          BillItem(id: 'i1', name: 'Lẩu', lineTotal: 200000, shares: {'me': 1, 'a': 1}),
        ],
      );

      final normalized = BillCalculator.normalizeParticipantPaidStates(payload);
      final zeroMember = normalized.participants.firstWhere((p) => p.id == 'z');
      expect(zeroMember.paid, isTrue);
      expect(zeroMember.paidAt, isNull);
      expect(
        BillCalculator.computePaymentStatus(normalized),
        PaymentStatus.settled,
      );

      // Edit bill so `z` now owes money -> auto-paid reverts to false, manual `a` stays paid
      final edited = normalized.copyWith(
        items: const [
          BillItem(
            id: 'i1',
            name: 'Lẩu',
            lineTotal: 300000,
            shares: {'me': 1, 'a': 1, 'z': 1},
          ),
        ],
      );
      final reNormalized = BillCalculator.normalizeParticipantPaidStates(edited);
      expect(reNormalized.participants.firstWhere((p) => p.id == 'z').paid, isFalse);
      expect(reNormalized.participants.firstWhere((p) => p.id == 'a').paid, isTrue);
      expect(
        BillCalculator.computePaymentStatus(reNormalized),
        PaymentStatus.pending,
      );
    });

    test('multi-payer hub-and-spoke via Host: A 100k, B 200k, C 50k, D 0, E 0 -> 70k each', () {
      const payload = BillPayload(
        participants: [
          Participant(id: 'a', name: 'A', isHost: true, paid: true, paidUpfront: 100000),
          Participant(id: 'b', name: 'B', paidUpfront: 200000),
          Participant(id: 'c', name: 'C', paidUpfront: 50000),
          Participant(id: 'd', name: 'D'),
          Participant(id: 'e', name: 'E'),
        ],
        items: [
          BillItem(
            id: 'equal_total',
            name: 'Equal split total',
            lineTotal: 350000,
            shares: {'a': 1, 'b': 1, 'c': 1, 'd': 1, 'e': 1},
          ),
        ],
        roundingMode: RoundingMode.none,
      );

      final res = BillCalculator.calculate(payload);
      expect(res.hasMultiPayer, isTrue);
      expect(res.totalPaidUpfront, 350000);
      expect(res.computedGrandTotal, 350000);

      for (final b in res.breakdowns) {
        expect(b.finalAmount, 70000);
      }
      expect(res.breakdownFor('a')!.netAmount, -30000);
      expect(res.breakdownFor('b')!.netAmount, -130000);
      expect(res.breakdownFor('b')!.isRefund, isTrue);
      expect(res.breakdownFor('b')!.refundAmount, 130000);
      expect(res.breakdownFor('b')!.collectAmount, 0);

      expect(res.breakdownFor('c')!.netAmount, 20000);
      expect(res.breakdownFor('c')!.collectAmount, 20000);
      expect(res.breakdownFor('d')!.netAmount, 70000);
      expect(res.breakdownFor('e')!.netAmount, 70000);

      expect(res.hostCollectTotal, 160000);
      expect(res.hostRefundTotal, 130000);
      expect(BillCalculator.computePaymentStatus(payload, calc: res), PaymentStatus.pending);

      // Even if C, D, E paid, bill remains pending until B is marked refunded
      final onlyCollected = payload.copyWith(
        participants: payload.participants
            .map((p) => (p.id == 'c' || p.id == 'd' || p.id == 'e') ? p.copyWith(paid: true) : p)
            .toList(),
      );
      expect(BillCalculator.computePaymentStatus(onlyCollected), PaymentStatus.pending);

      // Once B is also marked refunded -> bill is settled
      final allDone = onlyCollected.copyWith(
        participants: onlyCollected.participants
            .map((p) => p.id == 'b' ? p.copyWith(paid: true) : p)
            .toList(),
      );
      expect(BillCalculator.computePaymentStatus(allDone), PaymentStatus.settled);
    });

    test('multi-payer auto-marks exact-break-even member (paidUpfront == share) as paid', () {
      const payload = BillPayload(
        participants: [
          Participant(id: 'a', name: 'A', isHost: true, paid: true, paidUpfront: 140000),
          Participant(id: 'b', name: 'B', paidUpfront: 70000),
          Participant(id: 'c', name: 'C'),
        ],
        items: [
          BillItem(
            id: 'equal_total',
            name: 'Total',
            lineTotal: 210000,
            shares: {'a': 1, 'b': 1, 'c': 1},
          ),
        ],
        roundingMode: RoundingMode.none,
      );

      final normalized = BillCalculator.normalizeParticipantPaidStates(payload);
      expect(normalized.participants.firstWhere((p) => p.id == 'b').paid, isTrue);
      expect(normalized.participants.firstWhere((p) => p.id == 'c').paid, isFalse);
    });
  });
}

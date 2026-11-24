import 'package:flutter_test/flutter_test.dart';
import 'package:mam/core/person_ledger.dart';
import 'package:mam/models/bill_models.dart';

BillRecord _bill({
  required String id,
  required String title,
  String currencyCode = 'VND',
  required List<Participant> participants,
  required int totalAmount,
  DateTime? date,
}) {
  final d = date ?? DateTime(2026, 11, 24);
  return BillRecord(
    id: id,
    userId: 'u1',
    title: title,
    billDate: d,
    mode: BillMode.quickEqual,
    totalAmount: totalAmount,
    paymentStatus: PaymentStatus.pending,
    payload: BillPayload(
      currencyCode: currencyCode,
      roundingMode: RoundingMode.none,
      participants: participants,
      items: [
        BillItem(
          id: 'i1',
          name: 'Total',
          lineTotal: totalAmount,
          shares: {for (final p in participants) p.id: 1.0},
        ),
      ],
    ),
    createdAt: d,
    updatedAt: d,
  );
}

void main() {
  test('aggregates unpaid balances by contactId even after contact rename and falls back to normalized name for legacy bills', () {
    final now = DateTime.utc(2026, 11, 24);
    final contactMinh = MemberContact(
      id: 'c_minh',
      userId: 'u1',
      name: 'Minh Nguyễn',
      createdAt: now,
      updatedAt: now,
    );

    // Bill 1: uses contactId with old display name "Minh" -> owes 100k
    final b1 = _bill(
      id: 'b1',
      title: 'Bún chả',
      totalAmount: 200000,
      participants: const [
        Participant(id: 'p_host', name: 'Me', isHost: true, paid: true),
        Participant(id: 'p_1', name: 'Minh', contactId: 'c_minh', paid: false),
      ],
    );

    // Bill 2: multi-payer where Minh paid 150k out of 200k (share 100k) -> Host owes refund 50k
    final b2 = _bill(
      id: 'b2',
      title: 'Cà phê',
      totalAmount: 200000,
      participants: const [
        Participant(id: 'p_host', name: 'Me', isHost: true, paid: true, paidUpfront: 50000),
        Participant(id: 'p_2', name: 'Minh', contactId: 'c_minh', paid: false, paidUpfront: 150000),
      ],
    );

    // Bill 3: legacy bill without contactId, matching "Minh Nguyễn" via normalized name -> owes 40k
    final b3 = _bill(
      id: 'b3',
      title: 'Trà đá',
      totalAmount: 80000,
      participants: const [
        Participant(id: 'p_host', name: 'Me', isHost: true, paid: true),
        Participant(id: 'p_3', name: 'minh nguyen', paid: false),
      ],
    );

    final ledger = PersonLedgerCalculator.calculate(
      [b1, b2, b3],
      contacts: [contactMinh],
    );

    expect(ledger.summaries.length, 1);
    final summary = ledger.summaries.single;
    expect(summary.displayName, 'Minh Nguyễn');
    expect(summary.contactId, 'c_minh');
    expect(summary.collectTotal, 140000);
    expect(summary.refundTotal, 50000);
    expect(summary.netAmount, 90000);
    expect(summary.entries.length, 3);
    expect(summary.targets.length, 3);

    final memberSummaries = PersonLedgerCalculator.summariesForMember(
      contactMinh,
      [b1, b2, b3],
      contacts: [contactMinh],
    );
    expect(memberSummaries.single.netAmount, 90000);
  });

  test('separates VND and USD balances without mixing currencies', () {
    final bVnd = _bill(
      id: 'b_vnd',
      title: 'Phở',
      currencyCode: 'VND',
      totalAmount: 100000,
      participants: const [
        Participant(id: 'h', name: 'Me', isHost: true, paid: true),
        Participant(id: 'p', name: 'Lan', contactId: 'c_lan', paid: false),
      ],
    );
    final bUsd = _bill(
      id: 'b_usd',
      title: 'Coffee',
      currencyCode: 'USD',
      totalAmount: 2000, // $20.00
      participants: const [
        Participant(id: 'h', name: 'Me', isHost: true, paid: true),
        Participant(id: 'p', name: 'Lan', contactId: 'c_lan', paid: false),
      ],
    );

    final ledger = PersonLedgerCalculator.calculate([bVnd, bUsd]);
    expect(ledger.summaries.length, 2);
    expect(ledger.currencyCodes, containsAll(['VND', 'USD']));
    expect(ledger.forCurrency('VND').single.collectNet, 50000);
    expect(ledger.forCurrency('USD').single.collectNet, 1000);
  });
}

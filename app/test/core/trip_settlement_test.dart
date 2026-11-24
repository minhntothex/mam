import 'package:flutter_test/flutter_test.dart';
import 'package:mam/core/trip_settlement.dart';
import 'package:mam/models/bill_models.dart';

void main() {
  test('consolidates multi-bill trip with multi-payer netting by contactId and separates currencies', () {
    final now = DateTime.utc(2026, 11, 24);
    final contacts = [
      MemberContact(id: 'c_b', userId: 'u1', name: 'Bình', createdAt: now, updatedAt: now),
      MemberContact(id: 'c_c', userId: 'u1', name: 'Chi', createdAt: now, updatedAt: now),
    ];

    // Bill 1 (VND): total 300k split 3 ways (100k each). Host paid 100k, B paid 200k, C paid 0.
    // B net = -100k (Host refunds B 100k), C net = +100k (C pays Host 100k)
    final bill1 = BillRecord(
      id: 'b1',
      userId: 'u1',
      title: 'Lẩu gà lá é',
      billDate: DateTime(2026, 11, 24),
      mode: BillMode.quickEqual,
      totalAmount: 300000,
      paymentStatus: PaymentStatus.pending,
      payload: const BillPayload(
        tripName: 'Đà Lạt 24/11',
        roundingMode: RoundingMode.none,
        participants: [
          Participant(id: 'h', name: 'Me', isHost: true, paid: true, paidUpfront: 100000),
          Participant(id: 'p_b', name: 'Binh', contactId: 'c_b', paid: false, paidUpfront: 200000),
          Participant(id: 'p_c', name: 'Chi', contactId: 'c_c', paid: false, paidUpfront: 0),
        ],
        items: [
          BillItem(
            id: 'i1',
            name: 'Total',
            lineTotal: 300000,
            shares: {'h': 1, 'p_b': 1, 'p_c': 1},
          ),
        ],
      ),
      createdAt: now,
      updatedAt: now,
    );

    // Bill 2 (VND): total 150k split 3 ways (50k each), single payer Host.
    // B net = +50k, C net = +50k
    final bill2 = BillRecord(
      id: 'b2',
      userId: 'u1',
      title: 'Cà phê Tùng',
      billDate: DateTime(2026, 11, 24),
      mode: BillMode.quickEqual,
      totalAmount: 150000,
      paymentStatus: PaymentStatus.pending,
      payload: const BillPayload(
        tripName: 'Đà Lạt 24/11',
        roundingMode: RoundingMode.none,
        participants: [
          Participant(id: 'h', name: 'Me', isHost: true, paid: true),
          Participant(id: 'p_b2', name: 'Bình', contactId: 'c_b', paid: false),
          Participant(id: 'p_c2', name: 'Chi', contactId: 'c_c', paid: false),
        ],
        items: [
          BillItem(
            id: 'i2',
            name: 'Total',
            lineTotal: 150000,
            shares: {'h': 1, 'p_b2': 1, 'p_c2': 1},
          ),
        ],
      ),
      createdAt: now,
      updatedAt: now,
    );

    // Bill 3 (USD): $30 split between Host & Chi -> $15
    final bill3 = BillRecord(
      id: 'b3',
      userId: 'u1',
      title: 'Hotel Deposit',
      billDate: DateTime(2026, 11, 24),
      mode: BillMode.quickEqual,
      totalAmount: 3000,
      paymentStatus: PaymentStatus.pending,
      payload: const BillPayload(
        tripName: 'Đà Lạt 24/11',
        currencyCode: 'USD',
        roundingMode: RoundingMode.none,
        participants: [
          Participant(id: 'h', name: 'Me', isHost: true, paid: true),
          Participant(id: 'p_c3', name: 'Chi', contactId: 'c_c', paid: false),
        ],
        items: [
          BillItem(
            id: 'i3',
            name: 'Total',
            lineTotal: 3000,
            shares: {'h': 1, 'p_c3': 1},
          ),
        ],
      ),
      createdAt: now,
      updatedAt: now,
    );

    final result = TripSettlementCalculator.calculate(
      'Đà Lạt 24/11',
      [bill1, bill2, bill3],
      contacts: contacts,
    );

    expect(result.byCurrency.length, 2);

    final vnd = result.byCurrency.firstWhere((c) => c.currencyCode == 'VND');
    expect(vnd.totalSpend, 450000);
    expect(vnd.billCount, 2);
    expect(vnd.hostCollectRemaining, 150000); // Chi: +100k + +50k = +150k
    expect(vnd.hostRefundRemaining, 50000); // Bình: -100k + +50k = -50k

    final binh = vnd.people.firstWhere((p) => p.contactId == 'c_b');
    expect(binh.displayName, 'Bình');
    expect(binh.totalShare, 150000);
    expect(binh.totalUpfront, 200000);
    expect(binh.unpaidNetAmount, -50000);
    expect(binh.unpaidTargets.length, 2);

    final chi = vnd.people.firstWhere((p) => p.contactId == 'c_c');
    expect(chi.unpaidCollect, 150000);

    final usd = result.byCurrency.firstWhere((c) => c.currencyCode == 'USD');
    expect(usd.totalSpend, 3000);
    expect(usd.hostCollectRemaining, 1500);
  });
}

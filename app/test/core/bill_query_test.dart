import 'package:flutter_test/flutter_test.dart';
import 'package:mam/core/bill_query.dart';
import 'package:mam/models/bill_models.dart';

BillRecord _makeBill({
  required String id,
  required String title,
  required DateTime billDate,
  required DateTime updatedAt,
  PaymentStatus status = PaymentStatus.pending,
  DateTime? archivedAt,
  List<String> members = const ['Me', 'Minh'],
  List<String> items = const ['Hotpot'],
  String? note,
}) {
  return BillRecord(
    id: id,
    userId: 'u1',
    title: title,
    billDate: billDate,
    totalAmount: 100000,
    paymentStatus: status,
    payload: BillPayload(
      participants: [
        for (var i = 0; i < members.length; i++)
          Participant(id: 'p$i', name: members[i], isHost: i == 0),
      ],
      items: [
        for (var i = 0; i < items.length; i++)
          BillItem(id: 'i$i', name: items[i], lineTotal: 50000),
      ],
      note: note,
    ),
    createdAt: billDate,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );
}

void main() {
  test('compareBillsByPriority sorts Pending > Settled > Archived then updatedAt desc', () {
    final t1 = DateTime.utc(2026, 11, 20, 10);
    final t2 = DateTime.utc(2026, 11, 21, 10);
    final t3 = DateTime.utc(2026, 11, 22, 10);

    final pendingOld = _makeBill(
      id: 'p_old',
      title: 'Pending Old',
      billDate: t1,
      updatedAt: t1,
      status: PaymentStatus.pending,
    );
    final pendingNew = _makeBill(
      id: 'p_new',
      title: 'Pending New',
      billDate: t1,
      updatedAt: t2,
      status: PaymentStatus.pending,
    );
    final settledNew = _makeBill(
      id: 's_new',
      title: 'Settled New',
      billDate: t3,
      updatedAt: t3,
      status: PaymentStatus.settled,
    );
    final archivedPendingNewest = _makeBill(
      id: 'a_new',
      title: 'Archived Pending',
      billDate: t3,
      updatedAt: t3.add(const Duration(hours: 2)),
      status: PaymentStatus.pending,
      archivedAt: t3,
    );
    final archivedOlder = _makeBill(
      id: 'a_old',
      title: 'Archived Old',
      billDate: t1,
      updatedAt: t1,
      status: PaymentStatus.settled,
      archivedAt: t2,
    );

    final list = [
      archivedOlder,
      settledNew,
      pendingOld,
      archivedPendingNewest,
      pendingNew,
    ]..sort(compareBillsByPriority);

    expect(
      list.map((b) => b.id).toList(),
      ['p_new', 'p_old', 's_new', 'a_new', 'a_old'],
    );
  });

  test('matchesBillSearch matches title, Vietnamese diacritics, DD/MM/YY, member, item', () {
    final bill = _makeBill(
      id: 'b1',
      title: 'Lẩu Haidilao Bitexco',
      billDate: DateTime(2026, 11, 22),
      updatedAt: DateTime.utc(2026, 11, 22),
      members: ['Tôi', 'Minh Khôi', 'Lan'],
      items: ['Nước lẩu cà chua', 'Ba chỉ bò Mỹ'],
      note: 'Sinh nhật phòng',
    );

    expect(matchesBillSearch(bill, ''), isTrue);
    expect(matchesBillSearch(bill, 'haidilao'), isTrue);
    expect(matchesBillSearch(bill, 'LAU BITEXCO'), isTrue);
    expect(matchesBillSearch(bill, '22/11/26'), isTrue);
    expect(matchesBillSearch(bill, '22/11/2026'), isTrue);
    expect(matchesBillSearch(bill, 'minh khoi'), isTrue);
    expect(matchesBillSearch(bill, 'lan 22/11/26'), isTrue);
    expect(matchesBillSearch(bill, 'ba chi bo'), isTrue);
    expect(matchesBillSearch(bill, 'sinh nhat'), isTrue);
    expect(matchesBillSearch(bill, 'pizza'), isFalse);
    expect(matchesBillSearch(bill, '21/11/26'), isFalse);
  });
}

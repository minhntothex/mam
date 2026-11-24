import 'package:flutter_test/flutter_test.dart';
import 'package:mam/models/bill_models.dart';
import 'package:mam/services/sync_merger.dart';

void main() {
  group('SyncMerger.mergeByUpdatedAt', () {
    final t1 = DateTime.utc(2026, 11, 22, 10, 0);
    final t2 = DateTime.utc(2026, 11, 22, 11, 0);
    final t3 = DateTime.utc(2026, 11, 22, 12, 0);

    BillRecord bill(String id, String title, DateTime updatedAt, {DateTime? deletedAt}) {
      return BillRecord(
        id: id,
        userId: 'u1',
        title: title,
        billDate: DateTime(2026, 11, 22),
        totalAmount: 100000,
        payload: const BillPayload(participants: [], items: []),
        createdAt: t1,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
    }

    test('keeps newer record when remote and local conflict on same id', () {
      final local = [
        bill('b1', 'Local older', t1),
        bill('b2', 'Local newer', t3),
      ];
      final remote = [
        bill('b1', 'Remote newer', t2),
        bill('b2', 'Remote older', t2),
        bill('b3', 'Remote only', t2),
      ];

      final merged = SyncMerger.mergeByUpdatedAt<BillRecord>(
        local: local,
        remote: remote,
        idOf: (b) => b.id,
        updatedAtOf: (b) => b.updatedAt,
      );

      final byId = {for (final b in merged) b.id: b};
      expect(byId.length, 3);
      expect(byId['b1']!.title, 'Remote newer');
      expect(byId['b2']!.title, 'Local newer');
      expect(byId['b3']!.title, 'Remote only');
    });

    test('propagates soft-delete when deleted remote record is newer', () {
      final local = [bill('b1', 'Active locally', t1)];
      final remote = [bill('b1', 'Deleted on Android', t2, deletedAt: t2)];

      final merged = SyncMerger.mergeByUpdatedAt<BillRecord>(
        local: local,
        remote: remote,
        idOf: (b) => b.id,
        updatedAtOf: (b) => b.updatedAt,
      );

      expect(merged.single.isDeleted, isTrue);
      expect(merged.single.deletedAt, t2);
    });

    test('merges MemberContact records by updatedAt including soft-deletes', () {
      final local = [
        MemberContact(id: 'm1', userId: 'u1', name: 'Minh', createdAt: t1, updatedAt: t1),
        MemberContact(id: 'm2', userId: 'u1', name: 'Lan', createdAt: t1, updatedAt: t3),
      ];
      final remote = [
        MemberContact(id: 'm1', userId: 'u1', name: 'Minh Pro', createdAt: t1, updatedAt: t2),
        MemberContact(id: 'm2', userId: 'u1', name: 'Lan Old', createdAt: t1, updatedAt: t2),
        MemberContact(id: 'm3', userId: 'u1', name: 'Hùng', createdAt: t1, updatedAt: t2, deletedAt: t2),
      ];

      final merged = SyncMerger.mergeByUpdatedAt<MemberContact>(
        local: local,
        remote: remote,
        idOf: (m) => m.id,
        updatedAtOf: (m) => m.updatedAt,
      );
      final byId = {for (final m in merged) m.id: m};
      expect(byId['m1']!.name, 'Minh Pro');
      expect(byId['m2']!.name, 'Lan');
      expect(byId['m3']!.isDeleted, isTrue);
    });
  });
}

import '../models/bill_models.dart';
import 'vietqr.dart';

// Pure sorting & multi-field search helpers for Mâm bills.

/// Priority order: Pending (0) > Settled (1) > Archived (2),
/// then most recently updated first (`updatedAt` descending).
int compareBillsByPriority(BillRecord a, BillRecord b) {
  final rankDiff = _billStatusRank(a).compareTo(_billStatusRank(b));
  if (rankDiff != 0) return rankDiff;

  final updatedDiff = b.updatedAt.compareTo(a.updatedAt);
  if (updatedDiff != 0) return updatedDiff;

  final dateDiff = b.billDate.compareTo(a.billDate);
  if (dateDiff != 0) return dateDiff;

  return a.id.compareTo(b.id);
}

int _billStatusRank(BillRecord bill) {
  if (bill.isArchived) return 2;
  return bill.paymentStatus == PaymentStatus.pending ? 0 : 1;
}

/// Case-insensitive & Vietnamese diacritic-insensitive multi-token search across:
/// - bill title
/// - bill date & created date (`DD/MM/YY`, `DD/MM/YYYY`, `DD/MM`, `D/M/YY`)
/// - participant / member names
/// - item names and bill note
bool matchesBillSearch(BillRecord bill, String rawQuery) {
  final normalizedQuery = _normalize(rawQuery);
  if (normalizedQuery.isEmpty) return true;

  final tokens = normalizedQuery
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) return true;

  final buffer = StringBuffer()
    ..write(_normalize(bill.title))
    ..write(' ');

  _appendDateVariants(buffer, bill.billDate);
  _appendDateVariants(buffer, bill.createdAt.toLocal());

  for (final p in bill.payload.participants) {
    buffer
      ..write(_normalize(p.name))
      ..write(' ');
  }
  for (final item in bill.payload.items) {
    buffer
      ..write(_normalize(item.name))
      ..write(' ');
  }
  if (bill.payload.note != null && bill.payload.note!.isNotEmpty) {
    buffer
      ..write(_normalize(bill.payload.note!))
      ..write(' ');
  }

  final haystack = buffer.toString();
  for (final token in tokens) {
    if (!haystack.contains(token)) return false;
  }
  return true;
}

String _normalize(String input) =>
    VietQrGenerator.removeVietnameseDiacritics(input).toLowerCase().trim();

void _appendDateVariants(StringBuffer buffer, DateTime date) {
  final d = date.day;
  final m = date.month;
  final dd = d.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  final yyyy = date.year.toString();
  final yy = (date.year % 100).toString().padLeft(2, '0');

  buffer
    ..write('$dd/$mm/$yy ')
    ..write('$dd/$mm/$yyyy ')
    ..write('$dd/$mm ')
    ..write('$d/$m/$yy ')
    ..write('$d/$m/$yyyy ')
    ..write('$dd-$mm-$yy ')
    ..write('$dd-$mm-$yyyy ');
}

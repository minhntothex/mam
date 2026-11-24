import '../models/bill_models.dart';
import 'calculator.dart';
import 'currency.dart';
import 'vietqr.dart';

// Pure per-person debt aggregator across all pending bills.
// Links members by `Participant.contactId` first, falling back to normalized
// Vietnamese-diacritic-insensitive name for legacy v1.0.0 bills.

final class PersonBillDebtEntry {
  const PersonBillDebtEntry({
    required this.billId,
    required this.billTitle,
    required this.billDate,
    required this.participantId,
    required this.netAmount,
  });

  final String billId;
  final String billTitle;
  final DateTime billDate;
  final String participantId;

  /// Positive = member owes Host; negative = Host owes refund to member.
  final int netAmount;
}

final class PersonDebtSummary {
  const PersonDebtSummary({
    required this.personKey,
    required this.displayName,
    this.contactId,
    required this.currencyCode,
    required this.collectTotal,
    required this.refundTotal,
    required this.entries,
  });

  final String personKey;
  final String displayName;
  final String? contactId;
  final String currencyCode;
  final int collectTotal;
  final int refundTotal;
  final List<PersonBillDebtEntry> entries;

  /// Positive => member owes Host overall; negative => Host owes member refund.
  int get netAmount => collectTotal - refundTotal;
  int get collectNet => netAmount > 0 ? netAmount : 0;
  int get refundNet => netAmount < 0 ? -netAmount : 0;
  bool get isRefund => netAmount < 0;

  List<({String billId, String participantId})> get targets => entries
      .map((e) => (billId: e.billId, participantId: e.participantId))
      .toList(growable: false);
}

final class PersonLedgerResult {
  const PersonLedgerResult({required this.summaries});

  final List<PersonDebtSummary> summaries;

  bool get isEmpty => summaries.isEmpty;

  List<String> get currencyCodes {
    final codes = <String>[];
    for (final s in summaries) {
      if (!codes.contains(s.currencyCode)) codes.add(s.currencyCode);
    }
    return List.unmodifiable(codes);
  }

  List<PersonDebtSummary> forCurrency(String code) => summaries
      .where((s) => s.currencyCode == code)
      .toList(growable: false);
}

class PersonLedgerCalculator {
  const PersonLedgerCalculator._();

  static String normalizeName(String raw) =>
      VietQrGenerator.removeVietnameseDiacritics(raw).toLowerCase().trim();

  static ({String key, String displayName, String? contactId}) resolveIdentity({
    required Participant participant,
    required Map<String, MemberContact> contactsById,
    required Map<String, MemberContact> contactsByNormalizedName,
  }) {
    final cid = participant.contactId;
    if (cid != null && cid.isNotEmpty) {
      final matched = contactsById[cid];
      return (
        key: 'contact:$cid',
        displayName: matched?.name ?? participant.name.trim(),
        contactId: cid,
      );
    }
    final norm = normalizeName(participant.name);
    final byName = contactsByNormalizedName[norm];
    if (byName != null) {
      return (
        key: 'contact:${byName.id}',
        displayName: byName.name,
        contactId: byName.id,
      );
    }
    return (
      key: 'name:$norm',
      displayName: participant.name.trim(),
      contactId: null,
    );
  }

  static PersonLedgerResult calculate(
    List<BillRecord> pendingBills, {
    List<MemberContact> contacts = const [],
  }) {
    final contactsById = <String, MemberContact>{};
    final contactsByNorm = <String, MemberContact>{};
    for (final c in contacts) {
      if (c.isDeleted) continue;
      contactsById[c.id] = c;
      final norm = normalizeName(c.name);
      if (norm.isNotEmpty) contactsByNorm.putIfAbsent(norm, () => c);
    }

    final acc = <String, _PersonAccumulator>{};

    for (final bill in pendingBills) {
      if (bill.isDeleted || bill.isArchived) continue;
      final currencyCode = CurrencyRegistry.byCode(bill.payload.currencyCode).code;
      final calc = BillCalculator.calculate(bill.payload);

      for (final b in calc.breakdowns) {
        if (b.participant.isHost || b.participant.paid || b.netAmount == 0) {
          continue;
        }
        final identity = resolveIdentity(
          participant: b.participant,
          contactsById: contactsById,
          contactsByNormalizedName: contactsByNorm,
        );
        final bucketKey = '$currencyCode::${identity.key}';
        final bucket = acc.putIfAbsent(
          bucketKey,
          () => _PersonAccumulator(
            personKey: identity.key,
            displayName: identity.displayName,
            contactId: identity.contactId,
            currencyCode: currencyCode,
          ),
        );
        if (b.collectAmount > 0) {
          bucket.collectTotal += b.collectAmount;
        } else if (b.refundAmount > 0) {
          bucket.refundTotal += b.refundAmount;
        }
        bucket.entries.add(
          PersonBillDebtEntry(
            billId: bill.id,
            billTitle: bill.title,
            billDate: bill.billDate,
            participantId: b.participant.id,
            netAmount: b.netAmount,
          ),
        );
      }
    }

    final summaries = acc.values
        .map(
          (a) => PersonDebtSummary(
            personKey: a.personKey,
            displayName: a.displayName,
            contactId: a.contactId,
            currencyCode: a.currencyCode,
            collectTotal: a.collectTotal,
            refundTotal: a.refundTotal,
            entries: List.unmodifiable(a.entries),
          ),
        )
        .toList()
      ..sort((a, b) {
        // Collect balances first (descending), then refunds (descending abs), then even.
        final aRank = a.netAmount > 0 ? 0 : (a.netAmount < 0 ? 1 : 2);
        final bRank = b.netAmount > 0 ? 0 : (b.netAmount < 0 ? 1 : 2);
        if (aRank != bRank) return aRank.compareTo(bRank);
        final absDiff = b.netAmount.abs().compareTo(a.netAmount.abs());
        if (absDiff != 0) return absDiff;
        return a.displayName.compareTo(b.displayName);
      });

    return PersonLedgerResult(summaries: List.unmodifiable(summaries));
  }

  /// Returns all unsettled currency summaries for a specific saved [member].
  static List<PersonDebtSummary> summariesForMember(
    MemberContact member,
    List<BillRecord> pendingBills, {
    List<MemberContact> contacts = const [],
  }) {
    final effectiveContacts =
        contacts.any((c) => c.id == member.id) ? contacts : [...contacts, member];
    final ledger = calculate(pendingBills, contacts: effectiveContacts);
    final expectedKey = 'contact:${member.id}';
    return ledger.summaries
        .where((s) => s.personKey == expectedKey || s.contactId == member.id)
        .toList(growable: false);
  }
}

class _PersonAccumulator {
  _PersonAccumulator({
    required this.personKey,
    required this.displayName,
    required this.contactId,
    required this.currencyCode,
  });

  final String personKey;
  final String displayName;
  final String? contactId;
  final String currencyCode;
  int collectTotal = 0;
  int refundTotal = 0;
  final List<PersonBillDebtEntry> entries = [];
}

import '../models/bill_models.dart';
import 'calculator.dart';
import 'currency.dart';
import 'person_ledger.dart';

// Pure Trip / Event Settlement calculator aggregating multiple bills sharing a
// `tripName` into consolidated Hub-and-Spoke net settlements per currency.

final class TripBillLine {
  const TripBillLine({
    required this.billId,
    required this.billTitle,
    required this.billDate,
    required this.participantId,
    required this.shareAmount,
    required this.paidUpfront,
    required this.netAmount,
    required this.paid,
    required this.isHost,
  });

  final String billId;
  final String billTitle;
  final DateTime billDate;
  final String participantId;
  final int shareAmount;
  final int paidUpfront;
  final int netAmount;
  final bool paid;
  final bool isHost;
}

final class TripPersonSettlement {
  const TripPersonSettlement({
    required this.personKey,
    required this.displayName,
    this.contactId,
    required this.isHost,
    required this.totalShare,
    required this.totalUpfront,
    required this.totalNetAmount,
    required this.unpaidNetAmount,
    required this.billLines,
    required this.unpaidTargets,
  });

  final String personKey;
  final String displayName;
  final String? contactId;
  final bool isHost;
  final int totalShare;
  final int totalUpfront;

  /// Sum of net amounts across ALL bills in the trip (positive = owes Host,
  /// negative = Host refunds member).
  final int totalNetAmount;

  /// Remaining unsettled net amount across unpaid bills in the trip.
  final int unpaidNetAmount;

  final List<TripBillLine> billLines;
  final List<({String billId, String participantId})> unpaidTargets;

  int get unpaidCollect => unpaidNetAmount > 0 ? unpaidNetAmount : 0;
  int get unpaidRefund => unpaidNetAmount < 0 ? -unpaidNetAmount : 0;
  bool get isSettled => isHost || unpaidTargets.isEmpty;
}

final class TripCurrencySettlement {
  const TripCurrencySettlement({
    required this.tripName,
    required this.currencyCode,
    required this.bills,
    required this.people,
    required this.totalSpend,
    required this.settledBillCount,
    required this.hostCollectRemaining,
    required this.hostRefundRemaining,
  });

  final String tripName;
  final String currencyCode;
  final List<BillRecord> bills;
  final List<TripPersonSettlement> people;
  final int totalSpend;
  final int settledBillCount;
  final int hostCollectRemaining;
  final int hostRefundRemaining;

  int get billCount => bills.length;
}

final class TripSettlementResult {
  const TripSettlementResult({
    required this.tripName,
    required this.byCurrency,
  });

  final String tripName;
  final List<TripCurrencySettlement> byCurrency;

  bool get isEmpty => byCurrency.isEmpty;
}

class TripSettlementCalculator {
  const TripSettlementCalculator._();

  static TripSettlementResult calculate(
    String tripName,
    List<BillRecord> bills, {
    List<MemberContact> contacts = const [],
  }) {
    final contactsById = <String, MemberContact>{};
    final contactsByNorm = <String, MemberContact>{};
    for (final c in contacts) {
      if (c.isDeleted) continue;
      contactsById[c.id] = c;
      final norm = PersonLedgerCalculator.normalizeName(c.name);
      if (norm.isNotEmpty) contactsByNorm.putIfAbsent(norm, () => c);
    }

    final groupedBills = <String, List<BillRecord>>{};
    for (final bill in bills) {
      if (bill.isDeleted) continue;
      final code = CurrencyRegistry.byCode(bill.payload.currencyCode).code;
      groupedBills.putIfAbsent(code, () => <BillRecord>[]).add(bill);
    }

    final currencySettlements = <TripCurrencySettlement>[];

    for (final entry in groupedBills.entries) {
      final code = entry.key;
      final groupBills = List<BillRecord>.from(entry.value)
        ..sort((a, b) => b.billDate.compareTo(a.billDate));

      var totalSpend = 0;
      var settledCount = 0;
      final peopleMap = <String, _TripPersonAcc>{};

      for (final bill in groupBills) {
        final calc = BillCalculator.calculate(bill.payload);
        totalSpend += calc.computedGrandTotal;
        if (bill.paymentStatus == PaymentStatus.settled) {
          settledCount++;
        }

        for (final b in calc.breakdowns) {
          final isHost = b.participant.isHost;
          final identity = isHost
              ? (
                  key: 'host',
                  displayName: b.participant.name.trim(),
                  contactId: b.participant.contactId,
                )
              : PersonLedgerCalculator.resolveIdentity(
                  participant: b.participant,
                  contactsById: contactsById,
                  contactsByNormalizedName: contactsByNorm,
                );

          final acc = peopleMap.putIfAbsent(
            identity.key,
            () => _TripPersonAcc(
              personKey: identity.key,
              displayName: identity.displayName,
              contactId: identity.contactId,
              isHost: isHost,
            ),
          );

          acc.totalShare += b.finalAmount;
          acc.totalUpfront += b.paidUpfront;
          if (!isHost) {
            acc.totalNetAmount += b.netAmount;
            if (!b.participant.paid && b.netAmount != 0) {
              acc.unpaidNetAmount += b.netAmount;
              acc.unpaidTargets.add((
                billId: bill.id,
                participantId: b.participant.id,
              ));
            }
          }
          acc.billLines.add(
            TripBillLine(
              billId: bill.id,
              billTitle: bill.title,
              billDate: bill.billDate,
              participantId: b.participant.id,
              shareAmount: b.finalAmount,
              paidUpfront: b.paidUpfront,
              netAmount: b.netAmount,
              paid: isHost || b.participant.paid || b.netAmount == 0,
              isHost: isHost,
            ),
          );
        }
      }

      var hostCollectRemaining = 0;
      var hostRefundRemaining = 0;
      final people = peopleMap.values.map((a) {
        if (!a.isHost) {
          if (a.unpaidNetAmount > 0) {
            hostCollectRemaining += a.unpaidNetAmount;
          } else if (a.unpaidNetAmount < 0) {
            hostRefundRemaining += -a.unpaidNetAmount;
          }
        }
        return TripPersonSettlement(
          personKey: a.personKey,
          displayName: a.displayName,
          contactId: a.contactId,
          isHost: a.isHost,
          totalShare: a.totalShare,
          totalUpfront: a.totalUpfront,
          totalNetAmount: a.totalNetAmount,
          unpaidNetAmount: a.unpaidNetAmount,
          billLines: List.unmodifiable(a.billLines),
          unpaidTargets: List.unmodifiable(a.unpaidTargets),
        );
      }).toList()
        ..sort((a, b) {
          if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
          if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
          final netDiff =
              b.unpaidNetAmount.abs().compareTo(a.unpaidNetAmount.abs());
          if (netDiff != 0) return netDiff;
          return a.displayName.compareTo(b.displayName);
        });

      currencySettlements.add(
        TripCurrencySettlement(
          tripName: tripName,
          currencyCode: code,
          bills: List.unmodifiable(groupBills),
          people: List.unmodifiable(people),
          totalSpend: totalSpend,
          settledBillCount: settledCount,
          hostCollectRemaining: hostCollectRemaining,
          hostRefundRemaining: hostRefundRemaining,
        ),
      );
    }

    return TripSettlementResult(
      tripName: tripName,
      byCurrency: List.unmodifiable(currencySettlements),
    );
  }
}

class _TripPersonAcc {
  _TripPersonAcc({
    required this.personKey,
    required this.displayName,
    required this.contactId,
    required this.isHost,
  });

  final String personKey;
  final String displayName;
  final String? contactId;
  final bool isHost;
  int totalShare = 0;
  int totalUpfront = 0;
  int totalNetAmount = 0;
  int unpaidNetAmount = 0;
  final List<TripBillLine> billLines = [];
  final List<({String billId, String participantId})> unpaidTargets = [];
}

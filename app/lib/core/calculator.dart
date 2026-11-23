import '../models/bill_models.dart';
import 'currency.dart';

/// Pure bill-splitting calculator for Mâm.
///
/// Handles:
/// - Item-level discounts before share splitting
/// - Pro-rata allocation of VAT, service charge, pro-rata shipping, and bill discounts
/// - Flat per-head shipping allocation
/// - Unassigned item detection and division-by-zero guards
/// - Rounding to 1,000 VND (none / nearest / ceil) with transparent rounding delta
/// - OCR grand total reconciliation

final class ParticipantItemShare {
  const ParticipantItemShare({
    required this.itemId,
    required this.itemName,
    required this.weight,
    required this.totalWeight,
    required this.amount,
  });

  final String itemId;
  final String itemName;
  final double weight;
  final double totalWeight;
  final double amount;
}

final class ParticipantBreakdown {
  const ParticipantBreakdown({
    required this.participant,
    required this.itemShares,
    required this.itemsSubtotal,
    required this.proRataAdjustment,
    required this.flatAdjustment,
    required this.rawAmount,
    required this.finalAmount,
    this.paidUpfront = 0,
    required this.netAmount,
  });

  final Participant participant;
  final List<ParticipantItemShare> itemShares;
  final double itemsSubtotal;
  final double proRataAdjustment;
  final double flatAdjustment;
  final double rawAmount;

  /// This person's fair share of the bill after rounding.
  final int finalAmount;

  /// Amount this person paid out of pocket up front.
  final int paidUpfront;

  /// Net Hub-and-Spoke settlement relative to the Host:
  /// - `> 0`: person owes Host `netAmount`
  /// - `< 0`: Host refunds `-netAmount` to this person
  /// - `== 0`: already settled / even
  final int netAmount;

  bool get isRefund => !participant.isHost && netAmount < 0;
  int get collectAmount => netAmount > 0 ? netAmount : 0;
  int get refundAmount => netAmount < 0 ? -netAmount : 0;
}

final class BillCalculationResult {
  const BillCalculationResult({
    required this.breakdowns,
    required this.unassignedItems,
    required this.unassignedTotal,
    required this.assignedItemsSubtotal,
    required this.allItemsSubtotal,
    required this.computedGrandTotal,
    required this.assignedGrandTotal,
    required this.ocrDifference,
    required this.sumFinalAmounts,
    required this.roundingDelta,
    this.hasMultiPayer = false,
    this.totalPaidUpfront = 0,
    this.hostCollectTotal = 0,
    this.hostRefundTotal = 0,
  });

  /// Ordered list matching `payload.participants`.
  final List<ParticipantBreakdown> breakdowns;
  final List<BillItem> unassignedItems;
  final int unassignedTotal;
  final int assignedItemsSubtotal;
  final int allItemsSubtotal;

  /// `allItemsSubtotal + tax + serviceCharge + shipping - billDiscount` (clamped >= 0).
  final int computedGrandTotal;

  /// `assignedItemsSubtotal + tax + serviceCharge + shipping - billDiscount` (clamped >= 0).
  final int assignedGrandTotal;

  /// `computedGrandTotal - ocrGrandTotal` (null when OCR grand total is absent).
  final int? ocrDifference;

  /// Sum of all participants' `finalAmount`.
  final int sumFinalAmounts;

  /// `sumFinalAmounts - assignedGrandTotal`.
  /// Positive = host collects extra; negative = host absorbs shortfall.
  final int roundingDelta;

  /// True when at least one participant recorded an upfront payment.
  final bool hasMultiPayer;

  /// Sum of all participants' `paidUpfront`.
  final int totalPaidUpfront;

  /// Sum of positive `netAmount` owed by non-host participants to the Host.
  final int hostCollectTotal;

  /// Sum of `abs(netAmount)` that the Host refunds to overpaid non-host participants.
  final int hostRefundTotal;

  bool get hasUnassignedItems => unassignedItems.isNotEmpty;

  bool get isOcrMatched => ocrDifference == null || ocrDifference == 0;

  ParticipantBreakdown? breakdownFor(String participantId) {
    for (final b in breakdowns) {
      if (b.participant.id == participantId) return b;
    }
    return null;
  }
}

abstract final class BillCalculator {
  static BillCalculationResult calculate(BillPayload payload) {
    final participants = payload.participants;
    final participantIds = {for (final p in participants) p.id};
    final adj = payload.adjustments;

    final unassignedItems = <BillItem>[];
    var unassignedTotal = 0;
    var assignedItemsSubtotal = 0;
    var allItemsSubtotal = 0;

    final sharesByPerson = <String, List<ParticipantItemShare>>{
      for (final p in participants) p.id: <ParticipantItemShare>[],
    };
    final subtotalByPerson = <String, double>{
      for (final p in participants) p.id: 0.0,
    };

    for (final item in payload.items) {
      final net = item.netTotal;
      allItemsSubtotal += net;

      // Filter only shares belonging to existing participants with positive weight.
      final validEntries = item.shares.entries
          .where((e) => participantIds.contains(e.key) && e.value > 0)
          .toList(growable: false);

      final totalWeight =
          validEntries.fold<double>(0, (sum, entry) => sum + entry.value);

      if (totalWeight <= 0) {
        unassignedItems.add(item);
        unassignedTotal += net;
        continue;
      }

      assignedItemsSubtotal += net;
      for (final entry in validEntries) {
        final shareAmount = net * (entry.value / totalWeight);
        subtotalByPerson[entry.key] =
            (subtotalByPerson[entry.key] ?? 0.0) + shareAmount;
        sharesByPerson[entry.key]!.add(
          ParticipantItemShare(
            itemId: item.id,
            itemName: item.name,
            weight: entry.value,
            totalWeight: totalWeight,
            amount: shareAmount,
          ),
        );
      }
    }

    final proRataShipping =
        adj.shippingMode == ShippingSplitMode.proRata ? adj.shippingAmount : 0;
    final flatShipping =
        adj.shippingMode == ShippingSplitMode.flat ? adj.shippingAmount : 0;

    final proRataNet = adj.taxAmount +
        adj.serviceChargeAmount +
        proRataShipping -
        adj.billDiscountAmount;

    final rawComputedGrand = allItemsSubtotal +
        adj.taxAmount +
        adj.serviceChargeAmount +
        adj.shippingAmount -
        adj.billDiscountAmount;
    final computedGrandTotal = rawComputedGrand > 0 ? rawComputedGrand : 0;

    final rawAssignedGrand = assignedItemsSubtotal +
        adj.taxAmount +
        adj.serviceChargeAmount +
        adj.shippingAmount -
        adj.billDiscountAmount;
    final assignedGrandTotal = rawAssignedGrand > 0 ? rawAssignedGrand : 0;

    // Flat shipping splits across participants who actually ordered items;
    // falls back to all participants if nobody has items assigned yet.
    final activePayers = participants
        .where((p) => (subtotalByPerson[p.id] ?? 0.0) > 0)
        .map((p) => p.id)
        .toSet();
    final flatTargets = activePayers.isNotEmpty ? activePayers : participantIds;
    final flatPerHead =
        flatTargets.isNotEmpty ? flatShipping / flatTargets.length : 0.0;

    final breakdowns = <ParticipantBreakdown>[];
    var sumFinalAmounts = 0;
    final hasMultiPayer = participants.any((p) => p.paidUpfront > 0);
    var totalPaidUpfront = 0;
    var hostCollectTotal = 0;
    var hostRefundTotal = 0;

    final currency = CurrencyRegistry.byCode(payload.currencyCode);
    final roundingStep = currency.roundingStep;

    for (final participant in participants) {
      final itemsSub = subtotalByPerson[participant.id] ?? 0.0;
      final proRata = assignedItemsSubtotal > 0
          ? itemsSub * (proRataNet / assignedItemsSubtotal)
          : 0.0;
      final flat = flatTargets.contains(participant.id) ? flatPerHead : 0.0;
      final raw = itemsSub + proRata + flat;
      final clampedRaw = raw > 0 ? raw : 0.0;
      final finalAmt = roundAmount(
        clampedRaw,
        payload.roundingMode,
        step: roundingStep,
      );
      sumFinalAmounts += finalAmt;
      final upfront = participant.paidUpfront > 0 ? participant.paidUpfront : 0;
      totalPaidUpfront += upfront;

      final netAmt = hasMultiPayer
          ? (finalAmt - upfront)
          : (participant.isHost ? 0 : finalAmt);
      if (!participant.isHost) {
        if (netAmt > 0) {
          hostCollectTotal += netAmt;
        } else if (netAmt < 0) {
          hostRefundTotal += -netAmt;
        }
      }

      breakdowns.add(
        ParticipantBreakdown(
          participant: participant,
          itemShares: List.unmodifiable(sharesByPerson[participant.id]!),
          itemsSubtotal: itemsSub,
          proRataAdjustment: proRata,
          flatAdjustment: flat,
          rawAmount: clampedRaw,
          finalAmount: finalAmt,
          paidUpfront: upfront,
          netAmount: netAmt,
        ),
      );
    }

    final ocrDiff = adj.ocrGrandTotal == null
        ? null
        : computedGrandTotal - adj.ocrGrandTotal!;

    return BillCalculationResult(
      breakdowns: List.unmodifiable(breakdowns),
      unassignedItems: List.unmodifiable(unassignedItems),
      unassignedTotal: unassignedTotal,
      assignedItemsSubtotal: assignedItemsSubtotal,
      allItemsSubtotal: allItemsSubtotal,
      computedGrandTotal: computedGrandTotal,
      assignedGrandTotal: assignedGrandTotal,
      ocrDifference: ocrDiff,
      sumFinalAmounts: sumFinalAmounts,
      roundingDelta: sumFinalAmounts - assignedGrandTotal,
      hasMultiPayer: hasMultiPayer,
      totalPaidUpfront: totalPaidUpfront,
      hostCollectTotal: hostCollectTotal,
      hostRefundTotal: hostRefundTotal,
    );
  }

  static int roundAmount(double amount, RoundingMode mode, {int step = 1000}) {
    if (amount <= 0) return 0;
    final effectiveStep = step > 0 ? step : 1;
    return switch (mode) {
      RoundingMode.none => amount.round(),
      RoundingMode.ceil1000 => (amount / effectiveStep).ceil() * effectiveStep,
    };
  }

  /// Automatically marks non-host participants with 0 net settlement (`netAmount == 0`)
  /// as `paid: true` (`paidAt: null`). If a previously auto-paid member later
  /// owes or needs a refund on edit, resets `paid` to `false` while preserving
  /// manual paid marks (`paidAt != null`).
  static BillPayload normalizeParticipantPaidStates(
    BillPayload payload, {
    BillCalculationResult? calc,
  }) {
    final result = calc ?? calculate(payload);
    final netById = {
      for (final b in result.breakdowns) b.participant.id: b.netAmount,
    };
    var changed = false;
    final updated = payload.participants.map((p) {
      if (p.isHost) return p;
      final net = netById[p.id] ?? 0;
      if (net == 0) {
        if (!p.paid) {
          changed = true;
          return p.copyWith(paid: true, paidAt: null);
        }
        return p;
      }
      if (p.paid && p.paidAt == null) {
        changed = true;
        return p.copyWith(paid: false, paidAt: null);
      }
      return p;
    }).toList(growable: false);

    return changed ? payload.copyWith(participants: updated) : payload;
  }

  static PaymentStatus computePaymentStatus(
    BillPayload payload, {
    BillCalculationResult? calc,
  }) {
    if (payload.participants.isEmpty) return PaymentStatus.pending;
    final result = calc ?? calculate(payload);
    final allSettled = result.breakdowns.every(
      (b) => b.participant.isHost || b.participant.paid || b.netAmount == 0,
    );
    return allSettled ? PaymentStatus.settled : PaymentStatus.pending;
  }
}

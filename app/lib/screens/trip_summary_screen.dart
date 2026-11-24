import 'package:material_ui/material_ui.dart';

import '../core/currency.dart';
import '../core/formatters.dart';
import '../core/trip_settlement.dart';
import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import '../widgets/receipt_card.dart';
import 'result_screen.dart';

class TripSummaryScreen extends StatefulWidget {
  const TripSummaryScreen({
    super.key,
    required this.controller,
    required this.tripName,
    this.onOpenScanOcr,
  });

  final MamController controller;
  final String tripName;
  final Future<OcrScanResult?> Function(BuildContext context)? onOpenScanOcr;

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  String? _selectedCurrencyCode;
  final Set<String> _expandedKeys = <String>{};

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final tripBills = ctrl.billsForTrip(widget.tripName);
        final result = TripSettlementCalculator.calculate(
          widget.tripName,
          tripBills,
          contacts: ctrl.activeMembers,
        );

        if (result.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.tripName)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  s.emptyTripBills,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted),
                ),
              ),
            ),
          );
        }

        final activeCurrencyCode = result.byCurrency
                .any((c) => c.currencyCode == _selectedCurrencyCode)
            ? _selectedCurrencyCode!
            : result.byCurrency.first.currencyCode;
        final settlement = result.byCurrency.firstWhere(
          (c) => c.currencyCode == activeCurrencyCode,
        );
        final currency = CurrencyRegistry.byCode(settlement.currencyCode);
        final bankSnapshot = currency.supportsVietQr
            ? ctrl.defaultBankAccount?.toSnapshot()
            : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.tripName),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            children: [
              if (result.byCurrency.length > 1) ...[
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      for (final group in result.byCurrency)
                        ButtonSegment(
                          value: group.currencyCode,
                          label: Text(
                            CurrencyRegistry.byCode(group.currencyCode).label,
                          ),
                        ),
                    ],
                    selected: {activeCurrencyCode},
                    onSelectionChanged: (sel) =>
                        setState(() => _selectedCurrencyCode = sel.first),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.luggage_outlined,
                            size: 16,
                            color: p.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.tripBillsProgress(
                                settlement.settledBillCount,
                                settlement.billCount,
                              ),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: p.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.tripTotalSpend,
                        style: TextStyle(fontSize: 12, color: p.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatMoney(settlement.totalSpend, currency: currency),
                        style: kTabularStyle.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                      if (settlement.hostCollectRemaining > 0 ||
                          settlement.hostRefundRemaining > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: p.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: p.border),
                          ),
                          child: Text(
                            s.hostSettlementSummary(
                              formatMoney(
                                settlement.hostCollectRemaining,
                                currency: currency,
                              ),
                              formatMoney(
                                settlement.hostRefundRemaining,
                                currency: currency,
                              ),
                            ),
                            style: kTabularStyle.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.tripPerPersonSection,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < settlement.people.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TripPersonCard(
                    person: settlement.people[i],
                    currency: currency,
                    accentColor: p.participantColor(i),
                    expanded: _expandedKeys.contains(settlement.people[i].personKey),
                    onToggleExpand: () {
                      final key = settlement.people[i].personKey;
                      setState(() {
                        if (!_expandedKeys.add(key)) {
                          _expandedKeys.remove(key);
                        }
                      });
                    },
                    onShowQr: (!currency.supportsVietQr ||
                            settlement.people[i].isHost ||
                            settlement.people[i].unpaidCollect <= 0)
                        ? null
                        : () {
                            final person = settlement.people[i];
                            final unpaidLines = person.billLines
                                .where((l) => !l.paid && l.netAmount != 0)
                                .map((l) => (label: l.billTitle, amount: l.netAmount))
                                .toList(growable: false);
                            openCombinedPersonQrModal(
                              context,
                              headerTitle: widget.tripName,
                              personName: person.displayName,
                              amountVnd: person.unpaidCollect,
                              rawTransferNote:
                                  '${person.displayName} ${widget.tripName}',
                              bank: bankSnapshot,
                              lines: unpaidLines,
                            );
                          },
                    onMarkAllPaid: settlement.people[i].isSettled
                        ? null
                        : () async {
                            final person = settlement.people[i];
                            final updated = await ctrl.markPersonPaidAcrossBills(
                              person.unpaidTargets,
                            );
                            if (context.mounted && updated > 0) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      s.markedAllPaidSnack(
                                        person.displayName,
                                        updated,
                                      ),
                                    ),
                                  ),
                                );
                            }
                          },
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                s.tripBillsSection,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...settlement.bills.map(
                (bill) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      title: Text(
                        bill.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        formatDateVn(bill.billDate, includeYear: true),
                        style: TextStyle(fontSize: 12.5, color: p.muted),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMoney(bill.totalAmount, currency: currency),
                            style: kTabularStyle.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bill.paymentStatus == PaymentStatus.settled
                                ? s.settled
                                : s.paidProgress(
                                    bill.payload.participants
                                        .where((e) => e.isHost || e.paid)
                                        .length,
                                    bill.payload.participants.length,
                                  ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: bill.paymentStatus == PaymentStatus.settled
                                  ? p.success
                                  : p.warning,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ResultScreen(
                              controller: ctrl,
                              billId: bill.id,
                              onOpenScanOcr: widget.onOpenScanOcr,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TripPersonCard extends StatelessWidget {
  const _TripPersonCard({
    required this.person,
    required this.currency,
    required this.accentColor,
    required this.expanded,
    required this.onToggleExpand,
    this.onShowQr,
    this.onMarkAllPaid,
  });

  final TripPersonSettlement person;
  final CurrencySpec currency;
  final Color accentColor;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback? onShowQr;
  final VoidCallback? onMarkAllPaid;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final isRefund = !person.isHost && person.unpaidNetAmount < 0;
    final isSettled = person.isSettled;
    final hasActions = !isSettled && (onShowQr != null || onMarkAllPaid != null);

    final displayAmount = person.isHost
        ? formatMoney(person.totalShare, currency: currency)
        : (isSettled
            ? formatMoney(0, currency: currency)
            : (isRefund
                ? formatSignedMoney(-person.unpaidRefund, currency: currency)
                : formatMoney(person.unpaidCollect, currency: currency)));

    final amountColor = isSettled
        ? p.success
        : (isRefund ? p.warning : p.ink);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: hasActions && !expanded
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: accentColor.withValues(alpha: 0.16),
                    child: Text(
                      person.displayName.isEmpty
                          ? '?'
                          : person.displayName[0].toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              person.isHost
                                  ? '${person.displayName} (${s.host})'
                                  : person.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            if (isSettled && !person.isHost)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: p.successSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s.tripAllSettledPerson,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: p.success,
                                  ),
                                ),
                              )
                            else if (isRefund)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: p.warningSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s.refundBadge,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: p.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          person.totalUpfront > 0
                              ? s.shareAndUpfront(
                                  formatMoney(
                                    person.totalShare,
                                    currency: currency,
                                  ),
                                  formatMoney(
                                    person.totalUpfront,
                                    currency: currency,
                                  ),
                                )
                              : s.tripNetTotalLabel(
                                  formatMoney(
                                    person.totalShare,
                                    currency: currency,
                                  ),
                                ),
                          style: kTabularStyle.copyWith(
                            fontSize: 12,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayAmount,
                    style: kTabularStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: p.muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  for (final line in person.billLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Icon(
                            line.paid
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                            size: 14,
                            color: line.paid ? p.success : p.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${line.billTitle} (${formatDateVn(line.billDate)})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: p.ink),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            line.isHost
                                ? formatMoney(
                                    line.shareAmount,
                                    currency: currency,
                                  )
                                : formatSignedMoney(
                                    line.netAmount,
                                    currency: currency,
                                  ),
                            style: kTabularStyle.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: line.paid ? p.muted : p.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (hasActions) ...[
            Divider(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  if (onShowQr != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        onPressed: onShowQr,
                        icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                        label: Text(s.combinedQrBtn),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onMarkAllPaid != null)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        onPressed: onMarkAllPaid,
                        icon: const Icon(Icons.check_rounded, size: 17),
                        label: Text(
                          isRefund ? s.markAllRefundedBtn : s.markAllPaidBtn,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

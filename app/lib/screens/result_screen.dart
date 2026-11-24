import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/calculator.dart';
import '../core/currency.dart';
import '../core/export_png.dart';
import '../core/formatters.dart';
import '../core/vietqr.dart';
import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import '../widgets/receipt_card.dart';
import 'bill_input_screen.dart';
import 'quick_equal_screen.dart';
import 'settings_screen.dart';
import 'trip_summary_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.controller,
    required this.billId,
    this.onOpenScanOcr,
  });

  final MamController controller;
  final String billId;
  final Future<OcrScanResult?> Function(BuildContext context)? onOpenScanOcr;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final Set<String> _expandedPersonIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final bill = ctrl.findBillById(widget.billId);
        if (bill == null) {
          return Scaffold(
            appBar: AppBar(title: Text(s.resultTitle)),
            body: Center(child: Text(s.billNotFound)),
          );
        }

        final calc = BillCalculator.calculate(bill.payload);
        final currency = CurrencyRegistry.byCode(bill.payload.currencyCode);
        final stepLabel = s.isVi
            ? currency.roundingStepLabelVi
            : currency.roundingStepLabelEn;
        final activeBanks = ctrl.activeBankAccounts;
        final bankSnapshot = currency.supportsVietQr
            ? (bill.payload.bankAccountSnapshot ??
                ctrl.defaultBankAccount?.toSnapshot())
            : null;

        final paidCount = calc.breakdowns
            .where(
              (b) =>
                  b.participant.isHost ||
                  b.participant.paid ||
                  b.netAmount == 0,
            )
            .length;
        final totalPeople = bill.payload.participants.length;

        return Scaffold(
          appBar: AppBar(
            title: Text(bill.title),
            actions: [
              IconButton(
                tooltip: s.editBillTitle,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  if (bill.mode == BillMode.quickEqual) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuickEqualScreen(
                          controller: ctrl,
                          existingBill: bill,
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BillInputScreen(
                          controller: ctrl,
                          existingBill: bill,
                          onOpenScanOcr: widget.onOpenScanOcr,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${formatDateVn(bill.billDate, includeYear: true)} · ${s.paidProgress(paidCount, totalPeople)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatMoney(
                              calc.computedGrandTotal,
                              currency: currency,
                            ),
                            style: kTabularStyle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                            ),
                          ),
                        ],
                      ),
                      if (bill.payload.tripName != null &&
                          bill.payload.tripName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TripSummaryScreen(
                                  controller: ctrl,
                                  tripName: bill.payload.tripName!.trim(),
                                  onOpenScanOcr: widget.onOpenScanOcr,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: p.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.luggage_outlined,
                                  size: 14,
                                  color: p.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  bill.payload.tripName!.trim(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: p.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (bill.payload.note != null &&
                          bill.payload.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.notes_rounded,
                              size: 15,
                              color: p.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                bill.payload.note!.trim(),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontStyle: FontStyle.italic,
                                  color: p.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<RoundingMode>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: RoundingMode.none,
                              label: Text(s.roundNone),
                            ),
                            ButtonSegment(
                              value: RoundingMode.ceil1000,
                              label: Text(s.roundCeilStep(stepLabel)),
                            ),
                          ],
                          selected: {bill.payload.roundingMode},
                          onSelectionChanged: (sel) =>
                              ctrl.updateBillRounding(bill.id, sel.first),
                        ),
                      ),
                      if (calc.hasMultiPayer) ...[
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
                                calc.hostCollectTotal,
                                currency: currency,
                              ),
                              formatMoney(
                                calc.hostRefundTotal,
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
                      if (calc.roundingDelta != 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: p.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: p.border),
                          ),
                          child: Text(
                            s.roundingDeltaHost(
                              calc.roundingDelta > 0,
                              formatSignedMoney(
                                calc.roundingDelta,
                                currency: currency,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: p.muted,
                            ),
                          ),
                        ),
                      ],
                      if (currency.supportsVietQr) ...[
                        const SizedBox(height: 10),
                        Material(
                          color: p.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () =>
                                _pickBankSheet(context, bill, activeBanks),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_rounded,
                                    size: 16,
                                    color: p.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      bankSnapshot == null
                                          ? s.noBankAccountTap
                                          : s.receivingBank(
                                              bankSnapshot.bankShortName,
                                              bankSnapshot.accountNo,
                                            ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: p.ink,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 16,
                                    color: p.primary,
                                  ),
                                ],
                              ),
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
                s.perPersonDetails,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < calc.breakdowns.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ParticipantResultCard(
                    breakdown: calc.breakdowns[i],
                    currency: currency,
                    accentColor: p.participantColor(i),
                    hasMultiPayer: calc.hasMultiPayer,
                    expanded: _expandedPersonIds
                        .contains(calc.breakdowns[i].participant.id),
                    onToggleExpand: () {
                      final id = calc.breakdowns[i].participant.id;
                      setState(() {
                        if (!_expandedPersonIds.add(id)) {
                          _expandedPersonIds.remove(id);
                        }
                      });
                    },
                    onTogglePaid: (calc.breakdowns[i].participant.isHost ||
                            calc.breakdowns[i].netAmount == 0)
                        ? null
                        : () => ctrl.toggleParticipantPaid(
                              bill.id,
                              calc.breakdowns[i].participant.id,
                            ),
                    onShowQr: (!currency.supportsVietQr ||
                            calc.breakdowns[i].participant.isHost ||
                            calc.breakdowns[i].collectAmount <= 0)
                        ? null
                        : () => _openPersonQrModal(
                              context,
                              bill: bill,
                              breakdown: calc.breakdowns[i],
                              bank: bankSnapshot,
                            ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: Text(s.homeBtn),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openSummaryReceiptModal(
                        context,
                        bill: bill,
                        calc: calc,
                        bank: bankSnapshot,
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(
                        s.exportSummaryBtn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickBankSheet(
    BuildContext context,
    BillRecord bill,
    List<BankAccount> accounts,
  ) async {
    final s = context.s;
    if (accounts.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsScreen(controller: widget.controller),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              s.pickBankTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...accounts.map(
              (a) => ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.account_balance_rounded),
                title: Text(a.bankShortName),
                subtitle: Text(a.accountNo),
                onTap: () async {
                  await widget.controller.updateBillBankAccount(bill.id, a);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSummaryReceiptModal(
    BuildContext context, {
    required BillRecord bill,
    required BillCalculationResult calc,
    required BankAccountSnapshot? bank,
  }) async {
    final boundaryKey = GlobalKey();
    var exporting = false;
    final p = context.mam;
    final s = context.s;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.ground,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.receiptPreviewTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: RepaintBoundary(
                        key: boundaryKey,
                        child: SummaryReceiptCard(
                          bill: bill,
                          calc: calc,
                          bank: bank,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: exporting
                          ? null
                          : () async {
                              setModalState(() => exporting = true);
                              try {
                                final slug = VietQrGenerator.normalizeTransferNote(
                                  bill.title,
                                  maxLength: 24,
                                ).replaceAll(' ', '_');
                                await ReceiptPngExporter.shareBoundaryAsPng(
                                  boundaryKey: boundaryKey,
                                  fileName: 'mam_${slug.isEmpty ? 'bill' : slug}.png',
                                  shareText:
                                      '${bill.title} (${formatMoney(calc.computedGrandTotal, currency: CurrencyRegistry.byCode(bill.payload.currencyCode))})',
                                );
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text(s.exportError(e))),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setModalState(() => exporting = false);
                                }
                              }
                            },
                      icon: exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(exporting ? s.exportingPng : s.sharePngBtn),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPersonQrModal(
    BuildContext context, {
    required BillRecord bill,
    required ParticipantBreakdown breakdown,
    required BankAccountSnapshot? bank,
  }) async {
    final s = context.s;
    if (bank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.addBankFirst)),
      );
      return;
    }

    final boundaryKey = GlobalKey();
    final transferNote = VietQrGenerator.formatTransferNote(
      template: bill.payload.transferNoteTemplate,
      participantName: breakdown.participant.name,
      billTitle: bill.title,
    );
    var exporting = false;
    final p = context.mam;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.ground,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.personQrTitle(breakdown.participant.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: PersonQrCard(
                      bill: bill,
                      breakdown: breakdown,
                      bank: bank,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: bank.accountNo),
                          );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(s.copiedAccNo)),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text(s.copyAccNo),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: transferNote),
                          );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(s.copiedNote)),
                            );
                          }
                        },
                        icon: const Icon(Icons.notes_rounded, size: 16),
                        label: Text(s.copyNote),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: exporting
                        ? null
                        : () async {
                            setModalState(() => exporting = true);
                            try {
                              final slug = VietQrGenerator.normalizeTransferNote(
                                breakdown.participant.name,
                                maxLength: 16,
                              ).replaceAll(' ', '_');
                              await ReceiptPngExporter.shareBoundaryAsPng(
                                boundaryKey: boundaryKey,
                                fileName:
                                    'mam_qr_${slug.isEmpty ? 'person' : slug}.png',
                                shareText:
                                    '${breakdown.participant.name}: ${formatVnd(breakdown.collectAmount)} ($transferNote)',
                              );
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(s.exportError(e))),
                                );
                              }
                            } finally {
                              if (ctx.mounted) {
                                setModalState(() => exporting = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(
                      exporting ? s.exportingPng : s.sharePersonQrBtn,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantResultCard extends StatelessWidget {
  const _ParticipantResultCard({
    required this.breakdown,
    required this.currency,
    required this.accentColor,
    this.hasMultiPayer = false,
    required this.expanded,
    required this.onToggleExpand,
    this.onTogglePaid,
    this.onShowQr,
  });

  final ParticipantBreakdown breakdown;
  final CurrencySpec currency;
  final Color accentColor;
  final bool hasMultiPayer;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback? onTogglePaid;
  final VoidCallback? onShowQr;

  @override
  Widget build(BuildContext context) {
    final palette = context.mam;
    final s = context.s;
    final p = breakdown.participant;
    final isEven = breakdown.netAmount == 0;
    final isRefund = breakdown.isRefund;
    final paid = p.isHost || p.paid || isEven;
    final hasActionRow = !p.isHost && !isEven;

    final String? badgeLabel;
    final Color badgeBg;
    final Color badgeFg;
    if (isRefund) {
      badgeLabel = p.paid ? s.refunded : s.refundBadge;
      badgeBg = p.paid ? palette.successSoft : palette.warningSoft;
      badgeFg = p.paid ? palette.success : palette.warning;
    } else if (paid) {
      badgeLabel = s.paid;
      badgeBg = palette.successSoft;
      badgeFg = palette.success;
    } else {
      badgeLabel = null;
      badgeBg = Colors.transparent;
      badgeFg = Colors.transparent;
    }

    final displayAmount = p.isHost
        ? formatMoney(breakdown.finalAmount, currency: currency)
        : (isRefund
            ? formatSignedMoney(-breakdown.refundAmount, currency: currency)
            : formatMoney(breakdown.collectAmount, currency: currency));
    final amountColor = isRefund
        ? (p.paid ? palette.success : palette.warning)
        : (paid ? palette.success : palette.ink);
    final subtitleText = hasMultiPayer
        ? s.shareAndUpfront(
            formatMoney(breakdown.finalAmount, currency: currency),
            formatMoney(breakdown.paidUpfront, currency: currency),
          )
        : s.tapForDetails(breakdown.itemShares.length);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: hasActionRow && !expanded
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            onTap: onToggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: accentColor.withValues(alpha: 0.16),
                        child: Text(
                          p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
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
                                  p.isHost ? '${p.name} (${s.host})' : p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                if (badgeLabel != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      badgeLabel,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: badgeFg,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              subtitleText,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.muted,
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
                    ],
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 8),
                    ...breakdown.itemShares.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.itemName,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            Text(
                              formatMoney(
                                item.amount.round(),
                                currency: currency,
                              ),
                              style: kTabularStyle.copyWith(
                                fontSize: 12.5,
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (breakdown.proRataAdjustment.round() != 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.proRataLine,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: palette.muted,
                                ),
                              ),
                            ),
                            Text(
                              formatSignedMoney(
                                breakdown.proRataAdjustment.round(),
                                currency: currency,
                              ),
                              style: kTabularStyle.copyWith(
                                fontSize: 12.5,
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (breakdown.flatAdjustment.round() != 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.flatShipLine,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: palette.muted,
                                ),
                              ),
                            ),
                            Text(
                              formatSignedMoney(
                                breakdown.flatAdjustment.round(),
                                currency: currency,
                              ),
                              style: kTabularStyle.copyWith(
                                fontSize: 12.5,
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (hasActionRow)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTogglePaid,
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            paid ? palette.successSoft : palette.surface,
                        foregroundColor:
                            paid ? palette.success : palette.ink,
                        side: BorderSide(
                          color: paid ? palette.success : palette.border,
                        ),
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: Icon(
                        paid
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isRefund
                            ? (p.paid ? s.refunded : s.markRefunded)
                            : (paid ? s.paid : s.markPaid),
                      ),
                    ),
                  ),
                  if (onShowQr != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onShowQr,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.primarySoft,
                          foregroundColor: palette.primary,
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                        label: Text(s.personQrBtn),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

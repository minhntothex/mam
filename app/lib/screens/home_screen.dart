import 'package:material_ui/material_ui.dart';

import '../core/calculator.dart';
import '../core/formatters.dart';
import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import '../widgets/mam_logo.dart';
import 'bill_input_screen.dart';
import 'quick_equal_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';

enum _HomeFilter { all, pending, settled }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.onOpenScanOcr,
    this.syncAuthSectionBuilder,
  });

  final MamController controller;
  final Future<OcrScanResult?> Function(BuildContext context)? onOpenScanOcr;
  final Widget Function(BuildContext context)? syncAuthSectionBuilder;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeFilter _filter = _HomeFilter.all;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final brightness = Theme.of(context).brightness;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final bills = switch (_filter) {
          _HomeFilter.all => ctrl.activeBills,
          _HomeFilter.pending => ctrl.pendingBills,
          _HomeFilter.settled => ctrl.settledBills,
        };

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const MamLogoMark(size: 30),
                const SizedBox(width: 10),
                Text(s.appName),
              ],
            ),
            actions: [
              _SyncBadge(
                status: ctrl.syncStatus,
                onTap: () {
                  if (ctrl.signedInEmail != null) {
                    ctrl.triggerSync();
                  } else {
                    _openSettings(context);
                  }
                },
              ),
              IconButton(
                tooltip: brightness == Brightness.dark
                    ? s.switchToLight
                    : s.switchToDark,
                icon: Icon(
                  brightness == Brightness.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                onPressed: () => ctrl.toggleLightDark(brightness),
              ),
              IconButton(
                tooltip: s.settings,
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => _openSettings(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              if (ctrl.signedInEmail != null) {
                await ctrl.triggerSync();
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
              children: [
                _UncollectedBanner(
                  amount: ctrl.totalUncollectedAmount,
                  pendingCount: ctrl.pendingBills.length,
                ),
                const SizedBox(height: 16),
                _FilterBar(
                  selected: _filter,
                  allCount: ctrl.activeBills.length,
                  pendingCount: ctrl.pendingBills.length,
                  settledCount: ctrl.settledBills.length,
                  onChanged: (next) => setState(() => _filter = next),
                ),
                const SizedBox(height: 12),
                if (bills.isEmpty)
                  _EmptyBillsCard(filter: _filter)
                else
                  ...bills.map(
                    (bill) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BillHistoryCard(
                        bill: bill,
                        onTap: () => _openResult(context, bill.id),
                        onDelete: () => _confirmDelete(context, bill),
                      ),
                    ),
                  ),
              ],
            ),
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
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openQuickEqual(context),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(s.quickEqualBtn),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => _openNewBill(context),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: Text(s.newBillBtn),
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

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          controller: widget.controller,
          syncAuthSectionBuilder: widget.syncAuthSectionBuilder,
        ),
      ),
    );
  }

  void _openQuickEqual(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickEqualScreen(controller: widget.controller),
      ),
    );
  }

  void _openNewBill(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillInputScreen(
          controller: widget.controller,
          onOpenScanOcr: widget.onOpenScanOcr,
        ),
      ),
    );
  }

  void _openResult(BuildContext context, String billId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          controller: widget.controller,
          billId: billId,
          onOpenScanOcr: widget.onOpenScanOcr,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, BillRecord bill) async {
    final p = context.mam;
    final s = context.s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteBillTitle),
        content: Text(s.deleteBillConfirm(bill.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.danger,
              foregroundColor: p.onDanger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.deleteBill(bill.id);
    }
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.status, required this.onTap});

  final SyncStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final (label, bg, fg, icon) = switch (status) {
      SyncStatus.localOnly => (
          s.syncLocal,
          p.surfaceSubtle,
          p.muted,
          Icons.cloud_off_rounded,
        ),
      SyncStatus.synced => (
          s.syncSynced,
          p.successSoft,
          p.success,
          Icons.cloud_done_rounded,
        ),
      SyncStatus.pendingPush => (
          s.syncPending,
          p.warningSoft,
          p.warning,
          Icons.cloud_upload_rounded,
        ),
      SyncStatus.syncing => (
          s.syncSyncing,
          p.primarySoft,
          p.primary,
          Icons.sync_rounded,
        ),
      SyncStatus.error => (
          s.syncError,
          p.dangerSoft,
          p.danger,
          Icons.error_outline_rounded,
        ),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UncollectedBanner extends StatelessWidget {
  const _UncollectedBanner({
    required this.amount,
    required this.pendingCount,
  });

  final int amount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final allDone = pendingCount == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = allDone ? p.onHeroSettled : p.onHero;
    final pillBg = fg.withValues(alpha: 0.09);
    final dotColor =
        allDone ? const Color(0xFF146E52) : const Color(0xFFA15C00);
    final heroBorder = isDark
        ? null
        : Border.all(
            color: allDone
                ? const Color(0xFF8BE0BF)
                : const Color(0xFFF3D578),
          );
    final heroGradient = allDone
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFFC2F5DF), const Color(0xFF96E6C6)]
                : [const Color(0xFFD4F8E8), const Color(0xFFAEEED4)],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFFFCE8A6), const Color(0xFFF7D77E)]
                : [const Color(0xFFFFF3C4), const Color(0xFFFFE594)],
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: heroGradient,
        borderRadius: BorderRadius.circular(16),
        border: heroBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  allDone ? s.allSettledTitle : s.uncollectedTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg.withValues(alpha: allDone ? 0.88 : 0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      allDone
                          ? s.allSettledBadge
                          : s.pendingBillsBadge(pendingCount),
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatVnd(amount),
            style: kTabularStyle.copyWith(
              color: fg,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.allCount,
    required this.pendingCount,
    required this.settledCount,
    required this.onChanged,
  });

  final _HomeFilter selected;
  final int allCount;
  final int pendingCount;
  final int settledCount;
  final ValueChanged<_HomeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _pill(context, _HomeFilter.all, s.filterAll(allCount)),
          const SizedBox(width: 8),
          _pill(context, _HomeFilter.pending, s.filterPending(pendingCount)),
          const SizedBox(width: 8),
          _pill(context, _HomeFilter.settled, s.filterSettled(settledCount)),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, _HomeFilter value, String label) {
    final p = context.mam;
    final active = selected == value;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: active ? p.ink : p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? p.ink : p.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? p.ground : p.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BillHistoryCard extends StatelessWidget {
  const _BillHistoryCard({
    required this.bill,
    required this.onTap,
    required this.onDelete,
  });

  final BillRecord bill;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final participants = bill.payload.participants;
    final paidCount = participants.where((e) => e.isHost || e.paid).length;
    final totalPeople = participants.length;
    final progress = totalPeople == 0 ? 0.0 : paidCount / totalPeople;
    final settled = bill.paymentStatus == PaymentStatus.settled;
    final calc = BillCalculator.calculate(bill.payload);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.title,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${formatDateVn(bill.billDate, includeYear: true)} · ${bill.mode == BillMode.quickEqual ? s.equalSplitLabel : s.itemsCount(bill.payload.items.length)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatVnd(calc.computedGrandTotal),
                        style: kTabularStyle.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: onDelete,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: p.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: p.surfaceSubtle,
                        color: settled
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? p.success
                                : const Color(0xFF6FE3B5))
                            : (Theme.of(context).brightness == Brightness.dark
                                ? p.warning
                                : const Color(0xFFF7C95C)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: settled ? p.successSoft : p.warningSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      settled
                          ? s.settled
                          : s.paidProgress(paidCount, totalPeople),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: settled ? p.success : p.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBillsCard extends StatelessWidget {
  const _EmptyBillsCard({required this.filter});

  final _HomeFilter filter;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final text = switch (filter) {
      _HomeFilter.all => s.emptyAll,
      _HomeFilter.pending => s.emptyPending,
      _HomeFilter.settled => s.emptySettled,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 36, color: p.muted),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

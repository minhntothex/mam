import 'package:material_ui/material_ui.dart';

import '../core/bill_query.dart';
import '../core/calculator.dart';
import '../core/formatters.dart';
import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import '../widgets/mam_logo.dart';
import '../widgets/swipe_action_card.dart';
import 'bill_input_screen.dart';
import 'quick_equal_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';

enum _HomeFilter { all, pending, settled, archived }

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
  final TextEditingController _searchCtrl = TextEditingController();
  _HomeFilter _filter = _HomeFilter.all;
  String? _openSwipeBillId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final query = _searchCtrl.text.trim();

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final matchedAll = query.isEmpty
            ? ctrl.activeBills
            : ctrl.activeBills
                .where((b) => matchesBillSearch(b, query))
                .toList(growable: false);
        final matchedPending = matchedAll
            .where((b) => !b.isArchived && b.paymentStatus == PaymentStatus.pending)
            .toList(growable: false);
        final matchedSettled = matchedAll
            .where((b) => !b.isArchived && b.paymentStatus == PaymentStatus.settled)
            .toList(growable: false);
        final matchedArchived =
            matchedAll.where((b) => b.isArchived).toList(growable: false);

        final bills = switch (_filter) {
          _HomeFilter.all => matchedAll,
          _HomeFilter.pending => matchedPending,
          _HomeFilter.settled => matchedSettled,
          _HomeFilter.archived => matchedArchived,
        };

        final showAllWithDivider = _filter == _HomeFilter.all &&
            matchedArchived.isNotEmpty &&
            (matchedPending.isNotEmpty || matchedSettled.isNotEmpty);
        final nonArchivedInAll =
            showAllWithDivider ? [...matchedPending, ...matchedSettled] : const <BillRecord>[];

        return Scaffold(
          appBar: AppBar(
            title: const MamLogoMark(size: 32),
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
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (_) {
                if (_openSwipeBillId != null) {
                  setState(() => _openSwipeBillId = null);
                }
                return false;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
                children: [
                  _UncollectedBanner(
                    amount: ctrl.totalUncollectedAmount,
                    pendingCount: ctrl.pendingBills.length,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() => _openSwipeBillId = null),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: p.muted,
                      ),
                      hintText: s.searchBillsHint,
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: s.clearSearch,
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: p.muted,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _openSwipeBillId = null);
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FilterBar(
                    selected: _filter,
                    allCount: matchedAll.length,
                    pendingCount: matchedPending.length,
                    settledCount: matchedSettled.length,
                    archivedCount: matchedArchived.length,
                    onChanged: (next) => setState(() {
                      _filter = next;
                      _openSwipeBillId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (bills.isEmpty)
                    _EmptyBillsCard(
                      filter: _filter,
                      searchQuery: query,
                      onClearSearch: query.isEmpty
                          ? null
                          : () {
                              _searchCtrl.clear();
                              setState(() => _openSwipeBillId = null);
                            },
                    )
                  else if (showAllWithDivider) ...[
                    for (final bill in nonArchivedInAll)
                      _buildSwipeBillItem(context, bill),
                    _ArchivedSectionDivider(
                      label: s.archivedDivider(matchedArchived.length),
                    ),
                    for (final bill in matchedArchived)
                      _buildSwipeBillItem(context, bill),
                  ] else
                    for (final bill in bills)
                      _buildSwipeBillItem(context, bill),
                ],
              ),
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

  Widget _buildSwipeBillItem(BuildContext context, BillRecord bill) {
    final p = context.mam;
    final s = context.s;
    final isArchived = bill.isArchived;

    return Padding(
      key: ValueKey('bill_swipe_${bill.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: SwipeActionCard(
        isOpen: _openSwipeBillId == bill.id,
        onOpenChanged: (open) {
          setState(() {
            _openSwipeBillId = open ? bill.id : null;
          });
        },
        actions: [
          SwipeActionItem(
            label: isArchived ? s.restoreAction : s.archiveAction,
            icon: isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined,
            backgroundColor: isArchived ? p.successSoft : p.primarySoft,
            foregroundColor: isArchived ? p.success : p.primary,
            onTap: () => isArchived
                ? _handleRestore(context, bill)
                : _handleArchive(context, bill),
          ),
          SwipeActionItem(
            label: s.delete,
            icon: Icons.delete_outline_rounded,
            backgroundColor: p.dangerSoft,
            foregroundColor: p.danger,
            onTap: () => _confirmDelete(context, bill),
          ),
        ],
        child: _BillHistoryCard(
          bill: bill,
          onTap: () {
            if (_openSwipeBillId != null) {
              setState(() => _openSwipeBillId = null);
              return;
            }
            _openResult(context, bill.id);
          },
        ),
      ),
    );
  }

  Future<void> _handleArchive(BuildContext context, BillRecord bill) async {
    final s = context.s;
    await widget.controller.archiveBill(bill.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s.billArchivedSnack(bill.title)),
          action: SnackBarAction(
            label: s.undo,
            textColor: const Color(0xFFFFE594),
            onPressed: () => widget.controller.unarchiveBill(bill.id),
          ),
        ),
      );
  }

  Future<void> _handleRestore(BuildContext context, BillRecord bill) async {
    final s = context.s;
    await widget.controller.unarchiveBill(bill.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s.billRestoredSnack(bill.title)),
          action: SnackBarAction(
            label: s.undo,
            textColor: const Color(0xFFFFE594),
            onPressed: () => widget.controller.archiveBill(bill.id),
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
    final fg = allDone ? p.onHeroSettled : p.onHero;
    final pillBg = fg.withValues(alpha: 0.09);
    final dotColor =
        allDone ? const Color(0xFF146E52) : const Color(0xFFA15C00);
    final heroBorder = Border.all(
      color: allDone ? const Color(0xFF8BE0BF) : const Color(0xFFF3D578),
    );
    final heroGradient = allDone
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD4F8E8), Color(0xFFAEEED4)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF3C4), Color(0xFFFFE594)],
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
    required this.archivedCount,
    required this.onChanged,
  });

  final _HomeFilter selected;
  final int allCount;
  final int pendingCount;
  final int settledCount;
  final int archivedCount;
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
          const SizedBox(width: 8),
          _pill(context, _HomeFilter.archived, s.filterArchived(archivedCount)),
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
          color: active ? p.primary : p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? p.primary : p.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? p.onPrimary : p.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ArchivedSectionDivider extends StatelessWidget {
  const _ArchivedSectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: p.border, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: p.muted,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(child: Divider(color: p.border, thickness: 1)),
        ],
      ),
    );
  }
}

class _BillHistoryCard extends StatelessWidget {
  const _BillHistoryCard({
    required this.bill,
    required this.onTap,
  });

  final BillRecord bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final participants = bill.payload.participants;
    final paidCount = participants.where((e) => e.isHost || e.paid).length;
    final totalPeople = participants.length;
    final progress = totalPeople == 0 ? 0.0 : paidCount / totalPeople;
    final settled = bill.paymentStatus == PaymentStatus.settled;
    final archived = bill.isArchived;
    final calc = BillCalculator.calculate(bill.payload);

    final barColor = archived
        ? p.muted.withValues(alpha: 0.45)
        : (settled ? const Color(0xFF6FE3B5) : const Color(0xFFF7C95C));
    final badgeBg = archived
        ? p.surfaceSubtle
        : (settled ? p.successSoft : p.warningSoft);
    final badgeFg = archived
        ? p.muted
        : (settled ? p.success : p.warning);
    final badgeLabel = archived
        ? s.archived
        : (settled ? s.settled : s.paidProgress(paidCount, totalPeople));

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
                            color: archived ? p.muted : p.ink,
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
                  const SizedBox(width: 8),
                  Text(
                    formatVnd(calc.computedGrandTotal),
                    style: kTabularStyle.copyWith(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: archived ? p.muted : p.ink,
                    ),
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
                        color: barColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: badgeFg,
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
  const _EmptyBillsCard({
    required this.filter,
    this.searchQuery = '',
    this.onClearSearch,
  });

  final _HomeFilter filter;
  final String searchQuery;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final isSearch = searchQuery.isNotEmpty;
    final text = isSearch
        ? s.emptySearch(searchQuery)
        : switch (filter) {
            _HomeFilter.all => s.emptyAll,
            _HomeFilter.pending => s.emptyPending,
            _HomeFilter.settled => s.emptySettled,
            _HomeFilter.archived => s.emptyArchived,
          };
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            Icon(
              isSearch
                  ? Icons.search_off_rounded
                  : (filter == _HomeFilter.archived
                      ? Icons.archive_outlined
                      : Icons.receipt_long_outlined),
              size: 36,
              color: p.muted,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 13.5),
            ),
            if (isSearch && onClearSearch != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onClearSearch,
                child: Text(s.clearSearch),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../core/bill_query.dart';
import '../core/currency.dart';
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
        final nonArchivedInAll = showAllWithDivider
            ? [...matchedPending, ...matchedSettled]
            : const <BillRecord>[];

        final listEntries = <Object>[
          'banner',
          'filters',
          if (bills.isEmpty)
            'empty'
          else if (showAllWithDivider) ...[
            ...nonArchivedInAll,
            'archived_divider',
            ...matchedArchived,
          ] else
            ...bills,
        ];

        return Scaffold(
          drawer: _HomeMenuDrawer(
            controller: ctrl,
            onOpenSettings: () => _openSettings(context),
          ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: Row(
              children: [
                Builder(
                  builder: (ctx) => Tooltip(
                    message: s.menuTooltip,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: MamLogoMark(size: 34),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() => _openSwipeBillId = null),
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: p.muted,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        hintText: s.searchBillsHint,
                        hintStyle: TextStyle(fontSize: 13, color: p.muted),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: s.clearSearch,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: p.muted,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _openSwipeBillId = null);
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
                itemCount: listEntries.length,
                itemBuilder: (context, index) {
                  final entry = listEntries[index];
                  if (entry == 'banner') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _UncollectedBanner(
                        totalsByCurrency: ctrl.uncollectedByCurrency,
                        defaultCurrency: ctrl.currentCurrency,
                        pendingCount: ctrl.pendingBills.length,
                      ),
                    );
                  }
                  if (entry == 'filters') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FilterBar(
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
                    );
                  }
                  if (entry == 'empty') {
                    return _EmptyBillsCard(
                      filter: _filter,
                      searchQuery: query,
                      onClearSearch: query.isEmpty
                          ? null
                          : () {
                              _searchCtrl.clear();
                              setState(() => _openSwipeBillId = null);
                            },
                    );
                  }
                  if (entry == 'archived_divider') {
                    return _ArchivedSectionDivider(
                      label: s.archivedDivider(matchedArchived.length),
                    );
                  }
                  return RepaintBoundary(
                    child: _buildSwipeBillItem(context, entry as BillRecord),
                  );
                },
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
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),
                      onPressed: () => _openQuickEqual(context),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(
                        s.quickEqualBtn,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),
                      onPressed: () => _openNewBill(context),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: Text(
                        s.newBillBtn,
                        maxLines: 1,
                        softWrap: false,
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

class _HomeMenuDrawer extends StatelessWidget {
  const _HomeMenuDrawer({
    required this.controller,
    required this.onOpenSettings,
  });

  final MamController controller;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final signedIn = controller.signedInEmail != null;
    final currency = controller.currentCurrency;
    final formatLabel = switch (controller.amountInputFormat) {
      AmountInputFormat.auto => s.formatAuto,
      AmountInputFormat.dotThousands => s.formatDotThousands,
      AmountInputFormat.usdDecimal => s.formatUsdDecimal,
      AmountInputFormat.plain => s.formatPlain,
    };

    return Drawer(
      width: 292,
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const MamLogoMark(size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.panelSubtitle,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${controller.language.label} · ${currency.label}',
                          style: TextStyle(
                            fontSize: 12,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 14),
              Text(
                s.syncStatusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: p.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (signedIn) {
                      controller.triggerSync();
                    } else {
                      onOpenSettings();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _SyncBadge(
                              status: controller.syncStatus,
                              onTap: () {
                                Navigator.of(context).pop();
                                if (signedIn) {
                                  controller.triggerSync();
                                } else {
                                  onOpenSettings();
                                }
                              },
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: p.muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          signedIn
                              ? controller.signedInEmail!
                              : s.tapToConfigureSync,
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
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: p.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: p.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(Icons.tune_rounded, color: p.ink),
                  title: Text(
                    s.settings,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                  subtitle: Text(
                    '${currency.label} · $formatLabel',
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: p.muted,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenSettings();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    required this.totalsByCurrency,
    required this.defaultCurrency,
    required this.pendingCount,
  });

  final Map<String, int> totalsByCurrency;
  final CurrencySpec defaultCurrency;
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

    final primaryCode = totalsByCurrency.containsKey(defaultCurrency.code)
        ? defaultCurrency.code
        : (totalsByCurrency.isNotEmpty
            ? totalsByCurrency.keys.first
            : defaultCurrency.code);
    final primarySpec = CurrencyRegistry.byCode(primaryCode);
    final primaryAmount = totalsByCurrency[primaryCode] ?? 0;
    final secondaryEntries = totalsByCurrency.entries
        .where((e) => e.key != primaryCode && e.value > 0)
        .toList(growable: false);

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
            formatMoney(primaryAmount, currency: primarySpec),
            style: kTabularStyle.copyWith(
              color: fg,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          if (secondaryEntries.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              secondaryEntries
                  .map(
                    (e) =>
                        '+ ${formatMoney(e.value, currency: CurrencyRegistry.byCode(e.key))}',
                  )
                  .join(' · '),
              style: kTabularStyle.copyWith(
                color: fg.withValues(alpha: 0.82),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
          color: active ? p.primaryFill : p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? p.primaryFill : p.border,
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
    final currency = CurrencyRegistry.byCode(bill.payload.currencyCode);

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
                    formatMoney(bill.totalAmount, currency: currency),
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

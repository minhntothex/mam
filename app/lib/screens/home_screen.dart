import 'package:material_ui/material_ui.dart';

import '../core/bill_query.dart';
import '../core/currency.dart';
import '../core/formatters.dart';
import '../core/person_ledger.dart';
import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import '../widgets/mam_logo.dart';
import '../widgets/receipt_card.dart';
import '../widgets/swipe_action_card.dart';
import 'bill_input_screen.dart';
import 'members_screen.dart';
import 'quick_equal_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';
import 'trip_summary_screen.dart';

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
  final ScrollController _homeScrollCtrl = ScrollController();
  _HomeFilter _filter = _HomeFilter.all;
  String? _openSwipeBillId;

  /// Active page tab inside IndexedStack:
  /// 0 = Home, 1 = Members, 2 = Balances (per-person), 3 = Settings.
  int _tabIndex = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _homeScrollCtrl.dispose();
    super.dispose();
  }

  void _scrollHomeToTop() {
    if (_homeScrollCtrl.hasClients) {
      _homeScrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _openCreateActionSheet(BuildContext context) async {
    final p = context.mam;
    final s = context.s;

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.createSheetTitle,
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
              const SizedBox(height: 6),
              ListTile(
                key: const ValueKey('create_action_equal'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: CircleAvatar(
                  backgroundColor: p.primarySoft,
                  child: Icon(Icons.bolt_rounded, color: p.primary),
                ),
                title: Text(
                  s.quickEqualBtn,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  s.createEqualSub,
                  style: TextStyle(fontSize: 12.5, color: p.muted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => Navigator.pop(ctx, 'equal'),
              ),
              const SizedBox(height: 4),
              ListTile(
                key: const ValueKey('create_action_new_bill'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: CircleAvatar(
                  backgroundColor: p.primarySoft,
                  child: Icon(Icons.receipt_long_rounded, color: p.primary),
                ),
                title: Text(
                  s.newBillBtn,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  s.createNewBillSub,
                  style: TextStyle(fontSize: 12.5, color: p.muted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => Navigator.pop(ctx, 'new_bill'),
              ),
              if (widget.onOpenScanOcr != null) ...[
                const SizedBox(height: 4),
                ListTile(
                  key: const ValueKey('create_action_scan'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: p.primarySoft,
                    child: Icon(
                      Icons.document_scanner_rounded,
                      color: p.primary,
                    ),
                  ),
                  title: Text(
                    s.createScanTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    s.createScanSub,
                    style: TextStyle(fontSize: 12.5, color: p.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () => Navigator.pop(ctx, 'scan'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || action == null) return;
    if (action == 'equal') {
      _openQuickEqual(context);
    } else if (action == 'new_bill') {
      _openNewBill(context);
    } else if (action == 'scan' && widget.onOpenScanOcr != null) {
      final result = await widget.onOpenScanOcr!(context);
      if (result != null && context.mounted) {
        _openNewBill(context, initialOcrResult: result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        return Scaffold(
          body: IndexedStack(
            index: _tabIndex,
            children: [
              _buildHomeTab(context, ctrl),
              MembersScreen(controller: ctrl),
              _BalancesTab(controller: ctrl),
              SettingsScreen(
                controller: ctrl,
                syncAuthSectionBuilder: widget.syncAuthSectionBuilder,
                embeddedInTab: true,
              ),
            ],
          ),
          bottomNavigationBar: _MamBottomBar(
            tabIndex: _tabIndex,
            hasPendingBalances: ctrl.pendingBills.isNotEmpty,
            onSelectTab: (idx) {
              if (idx == 0 && _tabIndex == 0) {
                _scrollHomeToTop();
              } else {
                setState(() => _tabIndex = idx);
              }
            },
            onCreateTap: () => _openCreateActionSheet(context),
          ),
        );
      },
    );
  }

  Widget _buildHomeTab(BuildContext context, MamController ctrl) {
    final p = context.mam;
    final s = context.s;
    final query = _searchCtrl.text.trim();

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
    final activeTrips = ctrl.activeTripNames;

    final listEntries = <Object>[
      'banner',
      'filters',
      if (activeTrips.isNotEmpty) 'trips',
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: _scrollHomeToTop,
              child: const MamLogoMark(size: 40),
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
            controller: _homeScrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            itemCount: listEntries.length,
            itemBuilder: (context, index) {
              final entry = listEntries[index];
              if (entry == 'banner') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _UncollectedBanner(
                    totalsByCurrency: ctrl.uncollectedByCurrency,
                    toRefundByCurrency: ctrl.toRefundByCurrency,
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
              if (entry == 'trips') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TripsStrip(
                    trips: activeTrips,
                    onTapTrip: (tripName) => _openTripSummary(context, tripName),
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
    );
  }

  void _openTripSummary(BuildContext context, String tripName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripSummaryScreen(
          controller: widget.controller,
          tripName: tripName,
          onOpenScanOcr: widget.onOpenScanOcr,
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

  void _openNewBill(BuildContext context, {OcrScanResult? initialOcrResult}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillInputScreen(
          controller: widget.controller,
          initialOcrResult: initialOcrResult,
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

class _MamBottomBar extends StatelessWidget {
  const _MamBottomBar({
    required this.tabIndex,
    required this.hasPendingBalances,
    required this.onSelectTab,
    required this.onCreateTap,
  });

  final int tabIndex;
  final bool hasPendingBalances;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  key: const ValueKey('nav_home'),
                  icon: tabIndex == 0
                      ? Icons.receipt_long_rounded
                      : Icons.receipt_long_outlined,
                  label: s.navHome,
                  active: tabIndex == 0,
                  onTap: () => onSelectTab(0),
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  key: const ValueKey('nav_members'),
                  icon: tabIndex == 1
                      ? Icons.people_alt_rounded
                      : Icons.people_alt_outlined,
                  label: s.navMembers,
                  active: tabIndex == 1,
                  onTap: () => onSelectTab(1),
                ),
              ),
              Expanded(
                child: Center(
                  child: Tooltip(
                    message: s.createActionTooltip,
                    child: Material(
                      key: const ValueKey('nav_create_btn'),
                      color: p.primaryFill,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onCreateTap,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.add_rounded,
                            size: 26,
                            color: p.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  key: const ValueKey('nav_balances'),
                  icon: tabIndex == 2
                      ? Icons.account_balance_wallet_rounded
                      : Icons.account_balance_wallet_outlined,
                  label: s.navBalances,
                  active: tabIndex == 2,
                  badgeColor: hasPendingBalances ? p.warning : null,
                  onTap: () => onSelectTab(2),
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  key: const ValueKey('nav_settings'),
                  icon: tabIndex == 3
                      ? Icons.tune_rounded
                      : Icons.tune_outlined,
                  label: s.navSettings,
                  active: tabIndex == 3,
                  onTap: () => onSelectTab(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final fg = active ? p.primary : p.muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: fg),
                if (badgeColor != null)
                  Positioned(
                    right: -3,
                    top: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.surface, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalancesTab extends StatelessWidget {
  const _BalancesTab({required this.controller});

  final MamController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ledger = PersonLedgerCalculator.calculate(
          controller.pendingBills,
          contacts: controller.activeMembers,
        );

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(s.personLedgerTitle),
          ),
          body: ledger.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 40,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 40,
                          color: p.success,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.noUnsettledPeople,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.muted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: ledger.summaries.length,
                  itemBuilder: (context, index) {
                    final item = ledger.summaries[index];
                    final currency = CurrencyRegistry.byCode(item.currencyCode);
                    final isRefund = item.isRefund;
                    final bankSnapshot = currency.supportsVietQr
                        ? controller.defaultBankAccount?.toSnapshot()
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: p
                                        .participantColor(index)
                                        .withValues(alpha: 0.16),
                                    child: Text(
                                      item.displayName.isEmpty
                                          ? '?'
                                          : item.displayName[0].toUpperCase(),
                                      style: TextStyle(
                                        color: p.participantColor(index),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.displayName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          s.memberPendingBillsCount(
                                            item.entries.length,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: p.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    isRefund
                                        ? formatSignedMoney(
                                            -item.refundNet,
                                            currency: currency,
                                          )
                                        : formatMoney(
                                            item.collectNet,
                                            currency: currency,
                                          ),
                                    style: kTabularStyle.copyWith(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      color: isRefund ? p.warning : p.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              for (final entry in item.entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${entry.billTitle} (${formatDateVn(entry.billDate)})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: p.muted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        formatSignedMoney(
                                          entry.netAmount,
                                          currency: currency,
                                        ),
                                        style: kTabularStyle.copyWith(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: p.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (currency.supportsVietQr &&
                                      item.collectNet > 0) ...[
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: () {
                                          final lines = item.entries
                                              .map(
                                                (e) => (
                                                  label: e.billTitle,
                                                  amount: e.netAmount,
                                                ),
                                              )
                                              .toList(growable: false);
                                          openCombinedPersonQrModal(
                                            context,
                                            headerTitle: s.combinedBillsTitle(
                                              item.entries.length,
                                            ),
                                            personName: item.displayName,
                                            amountVnd: item.collectNet,
                                            rawTransferNote:
                                                s.combinedTransferNote(
                                              item.displayName,
                                              item.entries.length,
                                            ),
                                            bank: bankSnapshot,
                                            lines: lines,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.qr_code_2_rounded,
                                          size: 17,
                                        ),
                                        label: Text(s.combinedQrBtn),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final updated = await controller
                                            .markPersonPaidAcrossBills(
                                          item.targets,
                                        );
                                        if (context.mounted && updated > 0) {
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  s.markedAllPaidSnack(
                                                    item.displayName,
                                                    updated,
                                                  ),
                                                ),
                                              ),
                                            );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.check_rounded,
                                        size: 17,
                                      ),
                                      label: Text(
                                        isRefund
                                            ? s.markAllRefundedBtn
                                            : s.markAllPaidBtn,
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
                  },
                ),
        );
      },
    );
  }
}

class _TripsStrip extends StatelessWidget {
  const _TripsStrip({
    required this.trips,
    required this.onTapTrip,
  });

  final List<String> trips;
  final ValueChanged<String> onTapTrip;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < trips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            ActionChip(
              avatar: Icon(
                Icons.luggage_outlined,
                size: 15,
                color: p.primary,
              ),
              label: Text(
                trips[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              onPressed: () => onTapTrip(trips[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _UncollectedBanner extends StatelessWidget {
  const _UncollectedBanner({
    required this.totalsByCurrency,
    this.toRefundByCurrency = const {},
    required this.defaultCurrency,
    required this.pendingCount,
  });

  final Map<String, int> totalsByCurrency;
  final Map<String, int> toRefundByCurrency;
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
    final refundEntries = toRefundByCurrency.entries
        .where((e) => e.value > 0)
        .toList(growable: false);

    return Container(
      key: const ValueKey('uncollected_banner'),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
          if (refundEntries.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              s.toRefundBanner(
                refundEntries
                    .map(
                      (e) => formatMoney(
                        e.value,
                        currency: CurrencyRegistry.byCode(e.key),
                      ),
                    )
                    .join(' · '),
              ),
              style: kTabularStyle.copyWith(
                color: fg.withValues(alpha: 0.85),
                fontSize: 12.5,
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
    final tripName = bill.payload.tripName?.trim();

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
                          '${formatDateVn(bill.billDate, includeYear: true)} · ${bill.mode == BillMode.quickEqual ? s.equalSplitLabel : s.itemsCount(bill.payload.items.length)}${tripName != null && tripName.isNotEmpty ? ' · $tripName' : ''}',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

import 'package:material_ui/material_ui.dart';

import '../core/currency.dart';
import '../core/formatters.dart';
import '../core/person_ledger.dart';
import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import '../widgets/receipt_card.dart';

/// Persistent Members Directory (Danh bạ thành viên cố định) shown in Tab 2 of
/// the bottom bar. Supports search, add, rename, soft-delete, and live
/// per-person unpaid balance summary + Combined VietQR + Mark all paid.
class MembersScreen extends StatefulWidget {
  const MembersScreen({
    super.key,
    required this.controller,
  });

  final MamController controller;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final query = PersonLedgerCalculator.normalizeName(_searchCtrl.text);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final allMembers = ctrl.activeMembers;
        final filtered = query.isEmpty
            ? allMembers
            : allMembers
                .where(
                  (m) => PersonLedgerCalculator.normalizeName(m.name)
                      .contains(query),
                )
                .toList(growable: false);
        final pendingBills = ctrl.pendingBills;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(s.membersTitle),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  key: const ValueKey('members_add_btn'),
                  onPressed: () => _openMemberDialog(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(s.addMemberBtn),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (allMembers.length > 4)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
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
                        hintText: s.searchMembersHint,
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: p.muted,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
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
                                Icons.people_outline_rounded,
                                size: 40,
                                color: p.muted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                query.isEmpty
                                    ? s.emptyMembers
                                    : s.emptySearch(_searchCtrl.text.trim()),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: p.muted, fontSize: 13.5),
                              ),
                              if (query.isEmpty) ...[
                                const SizedBox(height: 14),
                                FilledButton.icon(
                                  onPressed: () => _openMemberDialog(context),
                                  icon: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 18,
                                  ),
                                  label: Text(s.addMemberBtn),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final member = filtered[index];
                          final summaries =
                              PersonLedgerCalculator.summariesForMember(
                            member,
                            pendingBills,
                            contacts: allMembers,
                          );
                          final primarySummary =
                              summaries.isNotEmpty ? summaries.first : null;
                          final accent = p.participantColor(index);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      accent.withValues(alpha: 0.16),
                                  child: Text(
                                    member.name.isEmpty
                                        ? '?'
                                        : member.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  member.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: primarySummary == null
                                    ? Text(
                                        s.memberClearedBadge,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: p.muted,
                                        ),
                                      )
                                    : _buildDebtSubtitle(
                                        context,
                                        primarySummary,
                                        summaries.length,
                                      ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await _openMemberDialog(
                                        context,
                                        existing: member,
                                      );
                                    } else if (value == 'delete') {
                                      await _confirmDelete(context, member);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(s.edit),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        s.delete,
                                        style: TextStyle(color: p.danger),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: primarySummary == null
                                    ? () => _openMemberDialog(
                                          context,
                                          existing: member,
                                        )
                                    : () => _openMemberDebtSheet(
                                          context,
                                          member: member,
                                          summaries: summaries,
                                        ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebtSubtitle(
    BuildContext context,
    PersonDebtSummary summary,
    int currencyCount,
  ) {
    final p = context.mam;
    final s = context.s;
    final currency = CurrencyRegistry.byCode(summary.currencyCode);
    final label = summary.isRefund
        ? s.memberRefundLabel(formatMoney(summary.refundNet, currency: currency))
        : s.memberOwesLabel(formatMoney(summary.collectNet, currency: currency));
    final suffix = currencyCount > 1
        ? ' (+${currencyCount - 1})'
        : ' · ${s.memberPendingBillsCount(summary.entries.length)}';
    return Text(
      '$label$suffix',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: kTabularStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: summary.isRefund ? p.warning : p.primary,
      ),
    );
  }

  Future<void> _openMemberDialog(
    BuildContext context, {
    MemberContact? existing,
  }) async {
    final s = context.s;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _MemberNameDialog(
        title: existing == null ? s.addMemberTitle : s.editMemberTitle,
        labelText: s.memberNameLabel,
        initialValue: existing?.name ?? '',
        cancelLabel: s.cancel,
        confirmLabel: s.save,
      ),
    );
    if (result == null || result.trim().isEmpty) return;

    if (existing == null) {
      await widget.controller.ensureMemberContact(result.trim());
    } else {
      await widget.controller.saveMemberContact(
        existing.copyWith(name: result.trim()),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MemberContact member,
  ) async {
    final p = context.mam;
    final s = context.s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteMemberTitle),
        content: Text(s.deleteMemberConfirm(member.name)),
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
      await widget.controller.deleteMemberContact(member.id);
    }
  }

  Future<void> _openMemberDebtSheet(
    BuildContext context, {
    required MemberContact member,
    required List<PersonDebtSummary> summaries,
  }) async {
    final p = context.mam;
    final s = context.s;
    final ctrl = widget.controller;

    await showModalBottomSheet<void>(
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
                      member.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
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
              for (final summary in summaries) ...[
                _MemberDebtSummaryBlock(
                  summary: summary,
                  bank: CurrencyRegistry.byCode(summary.currencyCode)
                          .supportsVietQr
                      ? ctrl.defaultBankAccount?.toSnapshot()
                      : null,
                  onMarkAllPaid: () async {
                    final updated = await ctrl.markPersonPaidAcrossBills(
                      summary.targets,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted && updated > 0) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              s.markedAllPaidSnack(member.name, updated),
                            ),
                          ),
                        );
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberDebtSummaryBlock extends StatelessWidget {
  const _MemberDebtSummaryBlock({
    required this.summary,
    required this.bank,
    required this.onMarkAllPaid,
  });

  final PersonDebtSummary summary;
  final BankAccountSnapshot? bank;
  final VoidCallback onMarkAllPaid;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final currency = CurrencyRegistry.byCode(summary.currencyCode);
    final isRefund = summary.isRefund;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isRefund ? s.totalToRefundLabel : s.totalToCollectLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: p.muted,
                  ),
                ),
              ),
              Text(
                isRefund
                    ? formatSignedMoney(-summary.refundNet, currency: currency)
                    : formatMoney(summary.collectNet, currency: currency),
                style: kTabularStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isRefund ? p.warning : p.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final entry in summary.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entry.billTitle} (${formatDateVn(entry.billDate)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: p.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatSignedMoney(entry.netAmount, currency: currency),
                    style: kTabularStyle.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p.muted,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (currency.supportsVietQr && summary.collectNet > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final lines = summary.entries
                          .map((e) => (label: e.billTitle, amount: e.netAmount))
                          .toList(growable: false);
                      openCombinedPersonQrModal(
                        context,
                        headerTitle:
                            s.combinedBillsTitle(summary.entries.length),
                        personName: summary.displayName,
                        amountVnd: summary.collectNet,
                        rawTransferNote: s.combinedTransferNote(
                          summary.displayName,
                          summary.entries.length,
                        ),
                        bank: bank,
                        lines: lines,
                      );
                    },
                    icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                    label: Text(s.combinedQrBtn),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: onMarkAllPaid,
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: Text(
                    isRefund ? s.markAllRefundedBtn : s.markAllPaidBtn,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberNameDialog extends StatefulWidget {
  const _MemberNameDialog({
    required this.title,
    required this.labelText,
    required this.initialValue,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String labelText;
  final String initialValue;
  final String cancelLabel;
  final String confirmLabel;

  @override
  State<_MemberNameDialog> createState() => _MemberNameDialogState();
}

class _MemberNameDialogState extends State<_MemberNameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _ctrl.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.pop(context, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: widget.labelText),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../core/amount_input_formatter.dart';
import '../core/calculator.dart';
import '../core/currency.dart';
import '../core/formatters.dart';
import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import 'result_screen.dart';

class SplitAssignScreen extends StatefulWidget {
  const SplitAssignScreen({
    super.key,
    required this.controller,
    this.existingBill,
    required this.title,
    required this.billDate,
    required this.items,
    required this.adjustments,
    this.currencyCode,
  });

  final MamController controller;
  final BillRecord? existingBill;
  final String title;
  final DateTime billDate;
  final List<BillItem> items;
  final BillAdjustments adjustments;
  final String? currencyCode;

  @override
  State<SplitAssignScreen> createState() => _SplitAssignScreenState();
}

class _SplitAssignScreenState extends State<SplitAssignScreen> {
  late List<Participant> _participants;
  late List<BillItem> _items;
  late String _selectedPersonId;
  String? _savedBillId;
  DateTime? _savedCreatedAt;

  CurrencySpec get _currency => CurrencyRegistry.byCode(
        widget.currencyCode ??
            widget.existingBill?.payload.currencyCode ??
            widget.controller.currentCurrency.code,
      );

  @override
  void initState() {
    super.initState();
    final existing = widget.existingBill;
    _savedBillId = existing?.id;
    _savedCreatedAt = existing?.createdAt;
    final s = widget.controller.strings;
    if (existing != null && existing.payload.participants.isNotEmpty) {
      _participants = List<Participant>.from(existing.payload.participants);
    } else if (widget.controller.activeFriendGroups.isNotEmpty) {
      final firstGroup = widget.controller.activeFriendGroups.first;
      _participants = firstGroup.members
          .map(
            (m) => Participant(
              id: 'p_${m.id}',
              name: m.name,
              isHost: m.isHost,
              paid: m.isHost,
            ),
          )
          .toList();
    } else {
      _participants = [
        Participant(id: 'p_me', name: s.me, isHost: true, paid: true),
      ];
    }

    _items = List<BillItem>.from(widget.items);
    _selectedPersonId = _participants.first.id;
  }

  BillPayload _currentPayload() {
    return BillPayload(
      participants: _participants,
      items: _items,
      adjustments: widget.adjustments,
      roundingMode: widget.existingBill?.payload.roundingMode ??
          widget.controller.settings.defaultRounding,
      currencyCode: _currency.code,
      bankAccountSnapshot: widget.existingBill?.payload.bankAccountSnapshot ??
          widget.controller.defaultBankAccount?.toSnapshot(),
      transferNoteTemplate: widget.existingBill?.payload.transferNoteTemplate ??
          widget.controller.settings.defaultTransferTemplate,
    );
  }

  Participant get _selectedPerson {
    return _participants.firstWhere(
      (p) => p.id == _selectedPersonId,
      orElse: () => _participants.first,
    );
  }

  void _togglePersonOnItem(int itemIndex) {
    final item = _items[itemIndex];
    final nextShares = Map<String, double>.from(item.shares);
    if ((nextShares[_selectedPersonId] ?? 0) > 0) {
      nextShares.remove(_selectedPersonId);
    } else {
      nextShares[_selectedPersonId] = 1;
    }
    setState(() {
      _items[itemIndex] = item.copyWith(shares: nextShares);
    });
  }

  void _adjustWeight(int itemIndex, double delta) {
    final item = _items[itemIndex];
    final nextShares = Map<String, double>.from(item.shares);
    final current = nextShares[_selectedPersonId] ?? 0;
    final updated = current + delta;
    if (updated <= 0) {
      nextShares.remove(_selectedPersonId);
    } else {
      nextShares[_selectedPersonId] = updated;
    }
    setState(() {
      _items[itemIndex] = item.copyWith(shares: nextShares);
    });
  }

  void _toggleAllTable(int itemIndex) {
    final item = _items[itemIndex];
    final allAssigned = _participants.every((p) => (item.shares[p.id] ?? 0) > 0);
    final nextShares = allAssigned
        ? <String, double>{}
        : {for (final p in _participants) p.id: 1.0};
    setState(() {
      _items[itemIndex] = item.copyWith(shares: nextShares);
    });
  }

  void _assignRemainingToAll() {
    setState(() {
      _items = _items.map((item) {
        if (item.isAssigned) return item;
        return item.copyWith(
          shares: {for (final p in _participants) p.id: 1.0},
        );
      }).toList();
    });
  }

  Future<void> _openMultiSelectSheet(int itemIndex) async {
    final item = _items[itemIndex];
    final selected = item.shares.keys.toSet();
    final palette = context.mam;
    final s = context.s;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.quickSplitItem(item.name),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _participants.length; i++)
                      FilterChip(
                        avatar: CircleAvatar(
                          backgroundColor: palette.participantColor(i),
                          radius: 6,
                        ),
                        label: Text(_participants[i].name),
                        selected: selected.contains(_participants[i].id),
                        onSelected: (val) {
                          setModalState(() {
                            if (val) {
                              selected.add(_participants[i].id);
                            } else {
                              selected.remove(_participants[i].id);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _items[itemIndex] = item.copyWith(
                          shares: {for (final id in selected) id: 1.0},
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(s.apply),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addPersonDialog() async {
    final s = context.s;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _AddPersonDialog(
        title: s.addPersonDialogTitle,
        hintText: s.personNameHint,
        cancelLabel: s.cancel,
        addLabel: s.add,
      ),
    );
    if (name == null || name.isEmpty) return;
    final newPerson = Participant(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
    );
    setState(() {
      _participants.add(newPerson);
      _selectedPersonId = newPerson.id;
    });
  }

  Future<void> _openUpfrontSheet() async {
    final updated = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UpfrontPaymentsSheet(
        participants: _participants,
        currency: _currency,
        inputFormat: widget.controller.amountInputFormat,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _participants = [
        for (final person in _participants)
          person.copyWith(paidUpfront: updated[person.id] ?? 0),
      ];
    });
  }

  Future<void> _pickGroupSheet() async {
    final s = context.s;
    final groups = widget.controller.activeFriendGroups;
    if (groups.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              s.pickGroupTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...groups.map(
              (g) => ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.groups_2_rounded),
                title: Text(g.name),
                subtitle: Text(g.members.map((m) => m.name).join(', ')),
                onTap: () {
                  setState(() {
                    _participants = g.members
                        .map(
                          (m) => Participant(
                            id: 'p_${m.id}',
                            name: m.name,
                            isHost: m.isHost,
                            paid: m.isHost,
                          ),
                        )
                        .toList();
                    _selectedPersonId = _participants.first.id;
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndFinish() async {
    final s = context.s;
    final calc = BillCalculator.calculate(_currentPayload());
    if (calc.hasUnassignedItems) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.unassignedDialogTitle),
          content: Text(
            s.unassignedDialogBody(
              calc.unassignedItems.length,
              formatMoney(calc.unassignedTotal, currency: _currency),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(s.backToAssign),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'assign_all'),
              child: Text(s.splitRemainingAll),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'continue'),
              child: Text(s.continueAnyway),
            ),
          ],
        ),
      );
      if (action == null || action == 'cancel') return;
      if (action == 'assign_all') {
        _assignRemainingToAll();
      }
    }

    final now = DateTime.now().toUtc();
    final billId = _savedBillId ?? widget.controller.newId();
    final createdAt = _savedCreatedAt ?? now;
    _savedBillId = billId;
    _savedCreatedAt = createdAt;
    final payload = _currentPayload();
    final record = BillRecord(
      id: billId,
      userId: widget.controller.currentUserId,
      title: widget.title,
      billDate: widget.billDate,
      mode: BillMode.itemized,
      totalAmount: BillCalculator.calculate(payload).computedGrandTotal,
      payload: payload,
      createdAt: createdAt,
      updatedAt: now,
      archivedAt: widget.existingBill?.archivedAt,
    );

    try {
      final saved = await widget.controller.saveBill(record);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            controller: widget.controller,
            billId: saved.id,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final calc = BillCalculator.calculate(_currentPayload());
    final selectedIdx = _participants
        .indexWhere((e) => e.id == _selectedPersonId)
        .clamp(0, _participants.length - 1);
    final selectedColor = p.participantColor(selectedIdx);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.assignTitle),
        actions: [
          TextButton.icon(
            key: const ValueKey('assign_upfront_btn'),
            onPressed: _openUpfrontSheet,
            icon: Icon(
              Icons.payments_outlined,
              size: 18,
              color: calc.hasMultiPayer ? p.primary : p.ink,
            ),
            label: Text(
              s.upfrontBtn,
              style: TextStyle(
                color: calc.hasMultiPayer ? p.primary : p.ink,
                fontWeight:
                    calc.hasMultiPayer ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          if (widget.controller.activeFriendGroups.isNotEmpty)
            TextButton.icon(
              onPressed: _pickGroupSheet,
              icon: const Icon(Icons.groups_2_outlined, size: 18),
              label: Text(s.groupsBtn),
            ),
          IconButton(
            tooltip: s.addPersonTooltip,
            onPressed: _addPersonDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _participants.length; i++) ...[
                        _ParticipantTabChip(
                          participant: _participants[i],
                          color: p.participantColor(i),
                          selected: _participants[i].id == _selectedPersonId,
                          subtotal:
                              calc.breakdownFor(_participants[i].id)?.finalAmount ?? 0,
                          currency: _currency,
                          onTap: () => setState(
                            () => _selectedPersonId = _participants[i].id,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      InkWell(
                        key: const ValueKey('inline_add_person_chip'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: _addPersonDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: p.surfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 16, color: p.primary),
                              const SizedBox(width: 4),
                              Text(
                                s.add,
                                style: TextStyle(
                                  color: p.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.assignGuide(_selectedPerson.name),
                        style: TextStyle(fontSize: 12, color: p.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final myWeight = item.shares[_selectedPersonId] ?? 0;
                final isMine = myWeight > 0;
                final allAssigned = _participants.every(
                  (person) => (item.shares[person.id] ?? 0) > 0,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isMine
                            ? selectedColor
                            : (item.isAssigned ? p.border : p.warning),
                        width: isMine ? 1.8 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _togglePersonOnItem(index),
                      onLongPress: () => _openMultiSelectSheet(index),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
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
                                        item.quantity > 1
                                            ? '${item.name}  ×${formatQty(item.quantity)}'
                                            : item.name,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (item.itemDiscount > 0)
                                        Text(
                                          s.itemDiscountApplied(
                                            formatMoney(
                                              item.itemDiscount,
                                              currency: _currency,
                                            ),
                                          ),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: p.success,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatMoney(item.netTotal, currency: _currency),
                                  style: kTabularStyle.copyWith(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 5,
                                    runSpacing: 5,
                                    children: [
                                      if (!item.isAssigned)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: p.warningSoft,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            s.unassigned,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: p.warning,
                                            ),
                                          ),
                                        )
                                      else
                                        for (var i = 0; i < _participants.length; i++)
                                          if ((item.shares[_participants[i].id] ?? 0) > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: p
                                                    .participantColor(i)
                                                    .withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                item.shares[_participants[i].id]! > 1
                                                    ? '${_participants[i].name} ×${formatQty(item.shares[_participants[i].id]!)}'
                                                    : _participants[i].name,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: p.participantColor(i),
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                                if (item.quantity > 1) ...[
                                  const SizedBox(width: 6),
                                  _QtyStepper(
                                    value: myWeight,
                                    color: selectedColor,
                                    onMinus: () => _adjustWeight(index, -1),
                                    onPlus: () => _adjustWeight(index, 1),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _toggleAllTable(index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: allAssigned ? p.ink : p.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      s.splitAllTable,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: allAssigned ? p.ground : p.ink,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: calc.hasUnassignedItems ? p.warningSoft : p.successSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      calc.hasUnassignedItems
                          ? Icons.info_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: calc.hasUnassignedItems ? p.warning : p.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        calc.hasUnassignedItems
                            ? s.unassignedSummary(
                                calc.unassignedItems.length,
                                formatMoney(
                                  calc.unassignedTotal,
                                  currency: _currency,
                                ),
                              )
                            : s.allAssignedSummary(_items.length),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: calc.hasUnassignedItems ? p.warning : p.success,
                        ),
                      ),
                    ),
                    if (calc.hasUnassignedItems)
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: _assignRemainingToAll,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            s.splitRemainingAll,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: p.warning,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveAndFinish,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(s.saveAndViewResult),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpfrontPaymentsSheet extends StatefulWidget {
  const _UpfrontPaymentsSheet({
    required this.participants,
    required this.currency,
    required this.inputFormat,
  });

  final List<Participant> participants;
  final CurrencySpec currency;
  final AmountInputFormat inputFormat;

  @override
  State<_UpfrontPaymentsSheet> createState() => _UpfrontPaymentsSheetState();
}

class _UpfrontPaymentsSheetState extends State<_UpfrontPaymentsSheet> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final p in widget.participants)
        p.id: TextEditingController(
          text: formatAmountForInput(
            p.paidUpfront,
            currency: widget.currency,
            format: widget.inputFormat,
          ),
        ),
    };
  }

  @override
  void dispose() {
    for (final ctrl in _ctrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final currency = widget.currency;
    final formatter = AmountTextInputFormatter(
      currency: currency,
      format: widget.inputFormat,
    );
    final zeroHint = currency.decimalDigits > 0 ? '0.00' : '0';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.upfrontSheetTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.upfrontSheetHint,
                style: TextStyle(fontSize: 12.5, color: p.muted),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < widget.participants.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: p.participantColor(i),
                        radius: 6,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.participants[i].isHost
                              ? '${widget.participants[i].name} (${s.host})'
                              : widget.participants[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 144,
                        child: TextField(
                          controller: _ctrls[widget.participants[i].id],
                          keyboardType: TextInputType.number,
                          inputFormatters: [formatter],
                          textAlign: TextAlign.right,
                          style: kTabularStyle.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: zeroHint,
                            hintStyle: kTabularStyle.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: p.muted.withValues(alpha: 0.35),
                            ),
                            prefixText: currency.symbolBefore
                                ? '${currency.symbol} '
                                : null,
                            suffixText: currency.symbolBefore
                                ? null
                                : currency.symbol,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final result = {
                      for (final entry in _ctrls.entries)
                        entry.key: parseAmountInput(entry.value.text),
                    };
                    Navigator.pop(context, result);
                  },
                  child: Text(s.apply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPersonDialog extends StatefulWidget {
  const _AddPersonDialog({
    required this.title,
    required this.hintText,
    required this.cancelLabel,
    required this.addLabel,
  });

  final String title;
  final String hintText;
  final String cancelLabel;
  final String addLabel;

  @override
  State<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<_AddPersonDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hintText),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(widget.addLabel),
        ),
      ],
    );
  }
}

class _ParticipantTabChip extends StatelessWidget {
  const _ParticipantTabChip({
    required this.participant,
    required this.color,
    required this.selected,
    required this.subtotal,
    required this.currency,
    required this.onTap,
  });

  final Participant participant;
  final Color color;
  final bool selected;
  final int subtotal;
  final CurrencySpec currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : p.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  participant.name,
                  style: TextStyle(
                    color: selected ? Colors.white : p.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                if (participant.isHost) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: selected ? Colors.white : color,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              formatMoney(subtotal, currency: currency),
              style: kTabularStyle.copyWith(
                color: selected ? Colors.white.withValues(alpha: 0.9) : p.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.color,
    required this.onMinus,
    required this.onPlus,
  });

  final double value;
  final Color color;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onMinus,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.remove, size: 15, color: color),
            ),
          ),
          Text(
            formatQty(value),
            style: kTabularStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPlus,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.add, size: 15, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

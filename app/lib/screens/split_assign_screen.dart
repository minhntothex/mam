import 'package:material_ui/material_ui.dart';

import '../core/calculator.dart';
import '../core/formatters.dart';
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
  });

  final MamController controller;
  final BillRecord? existingBill;
  final String title;
  final DateTime billDate;
  final List<BillItem> items;
  final BillAdjustments adjustments;

  @override
  State<SplitAssignScreen> createState() => _SplitAssignScreenState();
}

class _SplitAssignScreenState extends State<SplitAssignScreen> {
  late List<Participant> _participants;
  late List<BillItem> _items;
  late String _selectedPersonId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingBill;
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
        const Participant(id: 'p_me', name: 'Tôi', isHost: true, paid: true),
        const Participant(id: 'p_2', name: 'Minh'),
        const Participant(id: 'p_3', name: 'Lan'),
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
                  'Chia nhanh: ${item.name}',
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
                          backgroundColor: MamColors.participantColor(i),
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
                    child: const Text('Áp dụng'),
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
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm người vào mâm'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tên (vd: Trang)'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    ctrl.dispose();
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

  Future<void> _pickGroupSheet() async {
    final groups = widget.controller.activeFriendGroups;
    if (groups.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Chọn nhóm hay đi ăn',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...groups.map(
              (g) => ListTile(
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
    final calc = BillCalculator.calculate(_currentPayload());
    if (calc.hasUnassignedItems) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Còn món chưa gán'),
          content: Text(
            'Còn ${calc.unassignedItems.length} món (${formatVnd(calc.unassignedTotal)}) chưa chọn người ăn.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Quay lại gán'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'assign_all'),
              child: const Text('Chia cả bàn'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'continue'),
              child: const Text('Vẫn tiếp tục'),
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
    final existing = widget.existingBill;
    final payload = _currentPayload();
    final record = BillRecord(
      id: existing?.id ?? widget.controller.newId(),
      userId: widget.controller.currentUserId,
      title: widget.title,
      billDate: widget.billDate,
      mode: BillMode.itemized,
      totalAmount: BillCalculator.calculate(payload).computedGrandTotal,
      payload: payload,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final saved = await widget.controller.saveBill(record);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          controller: widget.controller,
          billId: saved.id,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final calc = BillCalculator.calculate(_currentPayload());
    final selectedIdx =
        _participants.indexWhere((p) => p.id == _selectedPersonId).clamp(0, _participants.length - 1);
    final selectedColor = MamColors.participantColor(selectedIdx);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gán món siêu tốc'),
        actions: [
          if (widget.controller.activeFriendGroups.isNotEmpty)
            TextButton.icon(
              onPressed: _pickGroupSheet,
              icon: const Icon(Icons.groups_2_outlined, size: 18),
              label: const Text('Nhóm'),
            ),
          IconButton(
            tooltip: 'Thêm người',
            onPressed: _addPersonDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sticky top participant selector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            decoration: const BoxDecoration(
              color: MamColors.paper,
              border: Border(bottom: BorderSide(color: MamColors.border)),
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
                          color: MamColors.participantColor(i),
                          selected: _participants[i].id == _selectedPersonId,
                          subtotal: calc.breakdownFor(_participants[i].id)?.finalAmount ?? 0,
                          onTap: () => setState(
                            () => _selectedPersonId = _participants[i].id,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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
                        'Chạm vào món để gán cho ${_selectedPerson.name} · Giữ lâu để chọn nhiều người',
                        style: const TextStyle(fontSize: 12, color: MamColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Item list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final myWeight = item.shares[_selectedPersonId] ?? 0;
                final isMine = myWeight > 0;
                final allAssigned = _participants.every(
                  (p) => (item.shares[p.id] ?? 0) > 0,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isMine
                            ? selectedColor
                            : (item.isAssigned ? MamColors.border : MamColors.amber),
                        width: isMine ? 1.8 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
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
                                          'Đã trừ giảm riêng ${formatVnd(item.itemDiscount)}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: MamColors.sage,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatVnd(item.netTotal),
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
                                            color: MamColors.amberSoft,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Chưa gán',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: MamColors.amber,
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
                                                color: MamColors.participantColor(i)
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
                                                  color: MamColors.participantColor(i),
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
                                      color: allAssigned
                                          ? MamColors.ink
                                          : MamColors.desk,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Cả bàn',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: allAssigned
                                            ? Colors.white
                                            : MamColors.ink,
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
          decoration: const BoxDecoration(
            color: MamColors.paper,
            border: Border(top: BorderSide(color: MamColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: calc.hasUnassignedItems
                      ? MamColors.amberSoft
                      : MamColors.sageSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      calc.hasUnassignedItems
                          ? Icons.info_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: calc.hasUnassignedItems
                          ? MamColors.amber
                          : MamColors.sage,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        calc.hasUnassignedItems
                            ? 'Còn ${calc.unassignedItems.length} món (${formatVnd(calc.unassignedTotal)}) chưa gán'
                            : 'Đã gán đủ tất cả ${_items.length} món',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: calc.hasUnassignedItems
                              ? MamColors.amber
                              : MamColors.sage,
                        ),
                      ),
                    ),
                    if (calc.hasUnassignedItems)
                      InkWell(
                        onTap: _assignRemainingToAll,
                        child: const Text(
                          'Chia cả bàn',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MamColors.amber,
                            decoration: TextDecoration.underline,
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
                  label: const Text('Lưu & Xem kết quả'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantTabChip extends StatelessWidget {
  const _ParticipantTabChip({
    required this.participant,
    required this.color,
    required this.selected,
    required this.subtotal,
    required this.onTap,
  });

  final Participant participant;
  final Color color;
  final bool selected;
  final int subtotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : MamColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : MamColors.border),
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
                    color: selected ? Colors.white : MamColors.ink,
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
              formatVnd(subtotal),
              style: kTabularStyle.copyWith(
                color: selected ? Colors.white.withValues(alpha: 0.9) : MamColors.muted,
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
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

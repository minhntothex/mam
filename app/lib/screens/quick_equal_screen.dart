import 'package:material_ui/material_ui.dart';

import '../core/calculator.dart';
import '../core/formatters.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import 'result_screen.dart';

class QuickEqualScreen extends StatefulWidget {
  const QuickEqualScreen({super.key, required this.controller});

  final MamController controller;

  @override
  State<QuickEqualScreen> createState() => _QuickEqualScreenState();
}

class _QuickEqualScreenState extends State<QuickEqualScreen> {
  late final TextEditingController _titleCtrl;
  final TextEditingController _totalCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();

  late RoundingMode _roundingMode;
  List<Participant> _participants = [
    const Participant(id: 'p_1', name: 'Tôi', isHost: true, paid: true),
    const Participant(id: 'p_2', name: 'Bạn 2'),
    const Participant(id: 'p_3', name: 'Bạn 3'),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: defaultMealTitle());
    _roundingMode = widget.controller.settings.defaultRounding;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _totalCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _totalAmount => parseVndInput(_totalCtrl.text);

  BillPayload _buildPayload() {
    final shares = {for (final p in _participants) p.id: 1.0};
    return BillPayload(
      participants: _participants,
      items: [
        BillItem(
          id: 'equal_total',
          name: 'Tổng hóa đơn chia đều',
          quantity: 1,
          lineTotal: _totalAmount,
          shares: shares,
        ),
      ],
      roundingMode: _roundingMode,
      bankAccountSnapshot: widget.controller.defaultBankAccount?.toSnapshot(),
      transferNoteTemplate: widget.controller.settings.defaultTransferTemplate,
    );
  }

  void _applyGroup(FriendGroup group) {
    setState(() {
      _participants = group.members
          .map(
            (m) => Participant(
              id: 'p_${m.id}',
              name: m.name,
              isHost: m.isHost,
              paid: m.isHost,
            ),
          )
          .toList();
    });
  }

  void _addParticipant() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _participants.add(
        Participant(
          id: 'p_${DateTime.now().microsecondsSinceEpoch}',
          name: name,
        ),
      );
      _nameCtrl.clear();
    });
  }

  void _setCount(int target) {
    if (target < 2 || target > 20) return;
    setState(() {
      if (target > _participants.length) {
        while (_participants.length < target) {
          final n = _participants.length + 1;
          _participants.add(
            Participant(
              id: 'p_${DateTime.now().microsecondsSinceEpoch}_$n',
              name: 'Bạn $n',
            ),
          );
        }
      } else {
        _participants = _participants.sublist(0, target);
      }
    });
  }

  Future<void> _submit() async {
    if (_totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tổng số tiền lớn hơn 0đ')),
      );
      return;
    }
    if (_participants.isEmpty) return;

    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final title = _titleCtrl.text.trim().isEmpty
        ? defaultMealTitle()
        : _titleCtrl.text.trim();

    final record = BillRecord(
      id: widget.controller.newId(),
      userId: widget.controller.currentUserId,
      title: title,
      billDate: today,
      mode: BillMode.quickEqual,
      totalAmount: _totalAmount,
      payload: _buildPayload(),
      createdAt: now,
      updatedAt: now,
    );

    final saved = await widget.controller.saveBill(record);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          controller: widget.controller,
          billId: saved.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final preview = BillCalculator.calculate(_buildPayload());
    final perPerson =
        preview.breakdowns.isNotEmpty ? preview.breakdowns.first.finalAmount : 0;
    final groups = widget.controller.activeFriendGroups;

    return Scaffold(
      appBar: AppBar(title: const Text('Chia đều siêu tốc')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tên bữa ăn',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: p.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(hintText: 'vd: Cà phê sáng'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tổng tiền hóa đơn (VNĐ)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: p.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _totalCtrl,
                    keyboardType: TextInputType.number,
                    style: kTabularStyle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      hintText: '300000',
                      suffixText: 'đ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [100000, 200000, 300000, 500000, 1000000].map((v) {
                      return ActionChip(
                        label: Text(formatVnd(v)),
                        onPressed: () {
                          _totalCtrl.text = v.toString();
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                          'Người tham gia (${_participants.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _setCount(_participants.length - 1),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _setCount(_participants.length + 1),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                  if (groups.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: groups.map((g) {
                        return ActionChip(
                          avatar: const Icon(Icons.groups_2_outlined, size: 16),
                          label: Text(g.name),
                          onPressed: () => _applyGroup(g),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < _participants.length; i++)
                        InputChip(
                          avatar: CircleAvatar(
                            backgroundColor: p.participantColor(i),
                            radius: 6,
                          ),
                          label: Text(
                            _participants[i].isHost
                                ? '${_participants[i].name} (Chủ xị)'
                                : _participants[i].name,
                          ),
                          selected: _participants[i].isHost,
                          selectedColor: p.primarySoft,
                          onPressed: () {
                            setState(() {
                              _participants = [
                                for (var j = 0; j < _participants.length; j++)
                                  _participants[j].copyWith(
                                    isHost: j == i,
                                    paid: j == i,
                                  ),
                              ];
                            });
                          },
                          onDeleted: _participants.length > 1
                              ? () => setState(() => _participants.removeAt(i))
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Thêm tên người...',
                          ),
                          onSubmitted: (_) => _addParticipant(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _addParticipant,
                        child: const Text('Thêm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chạm vào tên để đổi người làm Chủ xị.',
                    style: TextStyle(fontSize: 11.5, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Làm tròn số tiền',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<RoundingMode>(
                      segments: const [
                        ButtonSegment(value: RoundingMode.none, label: Text('Không')),
                        ButtonSegment(value: RoundingMode.nearest1000, label: Text('Gần 1k')),
                        ButtonSegment(value: RoundingMode.ceil1000, label: Text('Lên 1k')),
                      ],
                      selected: {_roundingMode},
                      onSelectionChanged: (s) =>
                          setState(() => _roundingMode = s.first),
                    ),
                  ),
                  if (_totalAmount > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Mỗi người trả:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatVnd(perPerson),
                                style: kTabularStyle.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: p.primary,
                                ),
                              ),
                              if (preview.roundingDelta != 0)
                                Text(
                                  'Lệch làm tròn: ${formatSignedVnd(preview.roundingDelta)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: p.muted,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
          child: FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Tạo kết quả & VietQR'),
          ),
        ),
      ),
    );
  }
}

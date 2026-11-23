import 'package:material_ui/material_ui.dart';

import '../core/amount_input_formatter.dart';
import '../core/calculator.dart';
import '../core/formatters.dart';
import '../l10n/mam_strings.dart';
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
  final Map<String, TextEditingController> _upfrontCtrls = {};

  late RoundingMode _roundingMode;
  late DateTime _billDate;
  late List<Participant> _participants;
  bool _multiPayer = false;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.strings;
    final now = DateTime.now();
    _billDate = DateTime(now.year, now.month, now.day);
    _titleCtrl = TextEditingController();
    _roundingMode = widget.controller.settings.defaultRounding;
    _participants = [
      Participant(id: 'p_1', name: s.me, isHost: true, paid: true),
    ];
    _upfrontCtrls['p_1'] = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _totalCtrl.dispose();
    _nameCtrl.dispose();
    for (final ctrl in _upfrontCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TextEditingController _upfrontCtrlFor(String participantId) {
    return _upfrontCtrls.putIfAbsent(
      participantId,
      TextEditingController.new,
    );
  }

  int _upfrontOf(String participantId) {
    if (!_multiPayer) return 0;
    final ctrl = _upfrontCtrls[participantId];
    if (ctrl == null) return 0;
    return parseAmountInput(ctrl.text);
  }

  int get _totalUpfrontAmount => _participants.fold<int>(
        0,
        (sum, p) => sum + _upfrontOf(p.id),
      );

  int get _effectiveTotalAmount =>
      _multiPayer ? _totalUpfrontAmount : parseVndInput(_totalCtrl.text);

  BillPayload _buildPayload(MamStrings s) {
    final total = _effectiveTotalAmount;
    final effectiveParticipants = [
      for (final p in _participants)
        p.copyWith(paidUpfront: _multiPayer ? _upfrontOf(p.id) : 0),
    ];
    final shares = {for (final p in effectiveParticipants) p.id: 1.0};
    return BillPayload(
      participants: effectiveParticipants,
      items: [
        BillItem(
          id: 'equal_total',
          name: s.equalTotalItemName,
          quantity: 1,
          lineTotal: total,
          shares: shares,
        ),
      ],
      roundingMode: _roundingMode,
      currencyCode: widget.controller.currentCurrency.code,
      bankAccountSnapshot: widget.controller.defaultBankAccount?.toSnapshot(),
      transferNoteTemplate: widget.controller.settings.defaultTransferTemplate,
    );
  }

  void _applyGroup(FriendGroup group) {
    setState(() {
      final next = group.members
          .map(
            (m) => Participant(
              id: 'p_${m.id}',
              name: m.name,
              isHost: m.isHost,
              paid: m.isHost,
            ),
          )
          .toList();
      final nextIds = {for (final p in next) p.id};
      final staleIds =
          _upfrontCtrls.keys.where((id) => !nextIds.contains(id)).toList();
      for (final id in staleIds) {
        _upfrontCtrls.remove(id)?.dispose();
      }
      for (final p in next) {
        _upfrontCtrlFor(p.id);
      }
      _participants = next;
    });
  }

  void _addParticipant() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final id = 'p_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _participants.add(Participant(id: id, name: name));
      _upfrontCtrlFor(id);
      _nameCtrl.clear();
    });
  }

  void _removeParticipant(int index) {
    if (_participants.length <= 1) return;
    setState(() {
      final removed = _participants.removeAt(index);
      _upfrontCtrls.remove(removed.id)?.dispose();
      if (removed.isHost && _participants.isNotEmpty) {
        _participants[0] = _participants[0].copyWith(isHost: true, paid: true);
      }
    });
  }

  void _setHost(int index) {
    setState(() {
      _participants = [
        for (var j = 0; j < _participants.length; j++)
          _participants[j].copyWith(
            isHost: j == index,
            paid: j == index,
          ),
      ];
    });
  }

  Future<void> _pickBillDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() {
        _billDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _submit() async {
    final s = context.s;
    final total = _effectiveTotalAmount;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _multiPayer ? s.enterPositiveUpfront : s.enterPositiveTotal,
          ),
        ),
      );
      return;
    }
    if (_participants.isEmpty) return;

    final now = DateTime.now().toUtc();
    final title = _titleCtrl.text.trim().isEmpty
        ? defaultMealTitle(isVi: s.isVi)
        : _titleCtrl.text.trim();

    final record = BillRecord(
      id: widget.controller.newId(),
      userId: widget.controller.currentUserId,
      title: title,
      billDate: _billDate,
      mode: BillMode.quickEqual,
      totalAmount: total,
      payload: _buildPayload(s),
      createdAt: now,
      updatedAt: now,
    );

    try {
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
    final currency = widget.controller.currentCurrency;
    final inputFormat = widget.controller.amountInputFormat;
    final amountFormatter = AmountTextInputFormatter(
      currency: currency,
      format: inputFormat,
    );
    final stepLabel = s.isVi
        ? currency.roundingStepLabelVi
        : currency.roundingStepLabelEn;
    final totalAmount = _effectiveTotalAmount;
    final preview = BillCalculator.calculate(_buildPayload(s));
    final perPerson =
        preview.breakdowns.isNotEmpty ? preview.breakdowns.first.finalAmount : 0;
    final groups = widget.controller.activeFriendGroups;
    final zeroHint = currency.decimalDigits > 0 ? '0.00' : '0';

    return Scaffold(
      appBar: AppBar(title: Text(s.quickEqualTitle)),
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
                    s.mealName,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: p.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      hintText: defaultMealTitle(isVi: s.isVi),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.billDateLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: p.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    key: const ValueKey('quick_equal_date_picker'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickBillDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: p.muted,
                        ),
                        suffixIcon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: p.muted,
                        ),
                      ),
                      child: Text(
                        formatDateVn(_billDate, includeYear: true),
                        style: kTabularStyle.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(s.singlePayerMode),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(s.multiPayerMode),
                        ),
                      ],
                      selected: {_multiPayer},
                      onSelectionChanged: (sel) =>
                          setState(() => _multiPayer = sel.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!_multiPayer) ...[
                    Text(
                      s.totalBillCurrency(currency.code),
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
                      inputFormatters: [amountFormatter],
                      style: kTabularStyle.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: zeroHint,
                        hintStyle: kTabularStyle.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: p.muted.withValues(alpha: 0.35),
                        ),
                        prefixText:
                            currency.symbolBefore ? '${currency.symbol} ' : null,
                        suffixText:
                            currency.symbolBefore ? null : currency.symbol,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: currency.quickPresets.map((v) {
                        return ActionChip(
                          label: Text(formatMoney(v, currency: currency)),
                          onPressed: () {
                            _totalCtrl.text = formatAmountForInput(
                              v,
                              currency: currency,
                              format: inputFormat,
                            );
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ] else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: p.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.autoTotalFromUpfront(
                                formatMoney(totalAmount, currency: currency),
                              ),
                              style: kTabularStyle.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                  Text(
                    s.participantsCount(_participants.length),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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
                  if (!_multiPayer)
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
                                  ? '${_participants[i].name} (${s.host})'
                                  : _participants[i].name,
                            ),
                            selected: _participants[i].isHost,
                            selectedColor: p.primarySoft,
                            onPressed: () => _setHost(i),
                            onDeleted: _participants.length > 1
                                ? () => _removeParticipant(i)
                                : null,
                          ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < _participants.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i < _participants.length - 1 ? 8 : 0,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _setHost(i),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor:
                                                p.participantColor(i),
                                            radius: 6,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              _participants[i].isHost
                                                  ? '${_participants[i].name} (${s.host})'
                                                  : _participants[i].name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight:
                                                    _participants[i].isHost
                                                        ? FontWeight.w700
                                                        : FontWeight.w600,
                                                color: _participants[i].isHost
                                                    ? p.primary
                                                    : p.ink,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 136,
                                  child: TextField(
                                    key: ValueKey(
                                      'upfront_${_participants[i].id}',
                                    ),
                                    controller:
                                        _upfrontCtrlFor(_participants[i].id),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [amountFormatter],
                                    textAlign: TextAlign.right,
                                    style: kTabularStyle.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
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
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                if (_participants.length > 1)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    onPressed: () => _removeParticipant(i),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: p.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(hintText: s.addPersonHint),
                          onSubmitted: (_) => _addParticipant(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _addParticipant,
                        child: Text(s.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.tapToChangeHost,
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
                  Text(
                    s.roundingLabel,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                      selected: {_roundingMode},
                      onSelectionChanged: (sel) =>
                          setState(() => _roundingMode = sel.first),
                    ),
                  ),
                  if (totalAmount > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.eachPersonPays,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatMoney(perPerson, currency: currency),
                                    style: kTabularStyle.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: p.primary,
                                    ),
                                  ),
                                  if (preview.roundingDelta != 0)
                                    Text(
                                      s.roundingDeltaShort(
                                        formatSignedMoney(
                                          preview.roundingDelta,
                                          currency: currency,
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: p.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (preview.hasMultiPayer &&
                              (preview.hostCollectTotal > 0 ||
                                  preview.hostRefundTotal > 0)) ...[
                            const SizedBox(height: 6),
                            Text(
                              s.hostSettlementSummary(
                                formatMoney(
                                  preview.hostCollectTotal,
                                  currency: currency,
                                ),
                                formatMoney(
                                  preview.hostRefundTotal,
                                  currency: currency,
                                ),
                              ),
                              style: kTabularStyle.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.muted,
                              ),
                            ),
                          ],
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
            label: Text(s.createResultQr),
          ),
        ),
      ),
    );
  }
}

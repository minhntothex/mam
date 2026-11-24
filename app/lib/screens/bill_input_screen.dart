import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/amount_input_formatter.dart';
import '../core/currency.dart';
import '../core/formatters.dart';
import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import 'split_assign_screen.dart';

class _EditableItemRow {
  _EditableItemRow({
    required this.id,
    String name = '',
    double quantity = 1,
    int unitPrice = 0,
    CurrencySpec currency = CurrencyRegistry.vnd,
    AmountInputFormat format = AmountInputFormat.auto,
    Map<String, double>? shares,
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: formatQty(quantity)),
        unitPriceCtrl = TextEditingController(
          text: formatAmountForInput(
            unitPrice,
            currency: currency,
            format: format,
          ),
        ),
        existingShares = shares ?? const {};

  factory _EditableItemRow.fromLineTotal({
    required String id,
    String name = '',
    double quantity = 1,
    int lineTotal = 0,
    CurrencySpec currency = CurrencyRegistry.vnd,
    AmountInputFormat format = AmountInputFormat.auto,
    Map<String, double>? shares,
  }) {
    final safeQty = quantity > 0 ? quantity : 1.0;
    final unitPrice = (lineTotal / safeQty).round();
    return _EditableItemRow(
      id: id,
      name: name,
      quantity: safeQty,
      unitPrice: unitPrice,
      currency: currency,
      format: format,
      shares: shares,
    );
  }

  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitPriceCtrl;
  final Map<String, double> existingShares;

  double get parsedQty {
    final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1;
    return qty > 0 ? qty : 1;
  }

  int get parsedUnitPrice => parseAmountInput(unitPriceCtrl.text);

  int get computedLineTotal => (parsedUnitPrice * parsedQty).round();

  BillItem toBillItem(String fallbackName) {
    return BillItem(
      id: id,
      name: nameCtrl.text.trim().isEmpty ? fallbackName : nameCtrl.text.trim(),
      quantity: parsedQty,
      lineTotal: computedLineTotal,
      shares: existingShares,
    );
  }

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    unitPriceCtrl.dispose();
  }
}

class BillInputScreen extends StatefulWidget {
  const BillInputScreen({
    super.key,
    required this.controller,
    this.existingBill,
    this.initialOcrResult,
    this.onOpenScanOcr,
  });

  final MamController controller;
  final BillRecord? existingBill;
  final OcrScanResult? initialOcrResult;
  final Future<OcrScanResult?> Function(BuildContext context)? onOpenScanOcr;

  @override
  State<BillInputScreen> createState() => _BillInputScreenState();
}

class _BillInputScreenState extends State<BillInputScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _tripCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _serviceCtrl;
  late final TextEditingController _shipCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _ocrTotalCtrl;
  late ShippingSplitMode _shippingMode;
  late DateTime _billDate;
  String? _ocrCurrencyOverride;
  final List<_EditableItemRow> _rows = [];
  bool _scanning = false;

  CurrencySpec get _currency => CurrencyRegistry.byCode(
        widget.existingBill?.payload.currencyCode ??
            _ocrCurrencyOverride ??
            widget.controller.currentCurrency.code,
      );

  AmountInputFormat get _inputFormat => widget.controller.amountInputFormat;

  String _fmtInput(int minor) => formatAmountForInput(
        minor,
        currency: _currency,
        format: _inputFormat,
      );

  @override
  void initState() {
    super.initState();
    final bill = widget.existingBill;
    final adj = bill?.payload.adjustments;

    _titleCtrl = TextEditingController(text: bill?.title ?? '');
    _noteCtrl = TextEditingController(text: bill?.payload.note ?? '');
    _tripCtrl = TextEditingController(text: bill?.payload.tripName ?? '');
    _billDate = bill?.billDate ?? DateTime.now();
    _taxCtrl = TextEditingController(text: _fmtInput(adj?.taxAmount ?? 0));
    _serviceCtrl =
        TextEditingController(text: _fmtInput(adj?.serviceChargeAmount ?? 0));
    _shipCtrl =
        TextEditingController(text: _fmtInput(adj?.shippingAmount ?? 0));
    _discountCtrl =
        TextEditingController(text: _fmtInput(adj?.billDiscountAmount ?? 0));
    _ocrTotalCtrl =
        TextEditingController(text: _fmtInput(adj?.ocrGrandTotal ?? 0));
    _shippingMode =
        adj?.shippingMode ?? widget.controller.settings.defaultShippingMode;

    if (bill != null && bill.payload.items.isNotEmpty) {
      for (final item in bill.payload.items) {
        _rows.add(
          _EditableItemRow.fromLineTotal(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            lineTotal: item.netTotal,
            currency: _currency,
            format: _inputFormat,
            shares: item.shares,
          ),
        );
      }
    } else if (widget.initialOcrResult != null) {
      _applyOcrResultFields(widget.initialOcrResult!);
    } else {
      _rows.add(_EditableItemRow(id: 'item_1'));
      _rows.add(_EditableItemRow(id: 'item_2'));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _tripCtrl.dispose();
    _taxCtrl.dispose();
    _serviceCtrl.dispose();
    _shipCtrl.dispose();
    _discountCtrl.dispose();
    _ocrTotalCtrl.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  int get _itemsSubtotal => _rows.fold<int>(
        0,
        (sum, r) => sum + r.toBillItem('Item').netTotal,
      );

  int get _computedGrandTotal {
    final total = _itemsSubtotal +
        parseVndInput(_taxCtrl.text) +
        parseVndInput(_serviceCtrl.text) +
        parseVndInput(_shipCtrl.text) -
        parseVndInput(_discountCtrl.text);
    return total > 0 ? total : 0;
  }

  int? get _ocrGrandTotal {
    final val = parseVndInput(_ocrTotalCtrl.text);
    return val > 0 ? val : null;
  }

  void _addRow() {
    setState(() {
      _rows.add(
        _EditableItemRow(id: 'item_${DateTime.now().microsecondsSinceEpoch}'),
      );
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      final removed = _rows.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _handleScanOcr() async {
    if (widget.onOpenScanOcr == null || _scanning) return;
    _scanning = true;
    try {
      final result = await widget.onOpenScanOcr!(context);
      if (result == null || !mounted) return;
      _applyOcrResult(result);
    } finally {
      _scanning = false;
    }
  }

  void _applyOcrResult(OcrScanResult result) {
    setState(() {
      _applyOcrResultFields(result);
    });
  }

  void _applyOcrResultFields(OcrScanResult result) {
    if (widget.existingBill == null && result.currencyCode != null) {
      final supported = CurrencyRegistry.all.any(
        (c) => c.code == result.currencyCode,
      );
      if (supported) {
        _ocrCurrencyOverride = result.currencyCode;
      }
    }
    if (result.title != null && result.title!.trim().isNotEmpty) {
      _titleCtrl.text = result.title!.trim();
    }
    if (result.billDate != null) {
      _billDate = result.billDate!;
    }
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
    for (var i = 0; i < result.items.length; i++) {
      final item = result.items[i];
      _rows.add(
        _EditableItemRow.fromLineTotal(
          id: 'ocr_${DateTime.now().microsecondsSinceEpoch}_$i',
          name: item.name,
          quantity: item.quantity,
          lineTotal: item.lineTotal > item.itemDiscount
              ? item.lineTotal - item.itemDiscount
              : item.lineTotal,
          currency: _currency,
          format: _inputFormat,
        ),
      );
    }
    if (_rows.isEmpty) {
      _rows.add(_EditableItemRow(id: 'item_1'));
    }
    _taxCtrl.text = _fmtInput(result.taxAmount);
    _serviceCtrl.text = _fmtInput(result.serviceChargeAmount);
    _shipCtrl.text = _fmtInput(result.shippingAmount);
    _discountCtrl.text = _fmtInput(result.billDiscountAmount);
    _ocrTotalCtrl.text = _fmtInput(result.ocrGrandTotal ?? 0);
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

  void _goToAssign() {
    final s = context.s;
    final items = _rows
        .map((r) => r.toBillItem(s.defaultItemName))
        .where((i) => i.lineTotal > 0)
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.needOneItem)),
      );
      return;
    }

    final adjustments = BillAdjustments(
      taxAmount: parseVndInput(_taxCtrl.text),
      serviceChargeAmount: parseVndInput(_serviceCtrl.text),
      shippingAmount: parseVndInput(_shipCtrl.text),
      shippingMode: _shippingMode,
      billDiscountAmount: parseVndInput(_discountCtrl.text),
      ocrGrandTotal: _ocrGrandTotal,
    );

    final title = _titleCtrl.text.trim().isEmpty
        ? defaultMealTitle(isVi: s.isVi)
        : _titleCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    final tripName = _tripCtrl.text.trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SplitAssignScreen(
          controller: widget.controller,
          existingBill: widget.existingBill,
          title: title,
          billDate: _billDate,
          items: items,
          adjustments: adjustments,
          currencyCode: _currency.code,
          note: note.isEmpty ? null : note,
          tripName: tripName.isEmpty ? null : tripName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;
    final currency = _currency;
    final amountFormatter = AmountTextInputFormatter(
      currency: currency,
      format: _inputFormat,
    );
    final qtyFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
    final prefixSymbol = currency.symbolBefore ? '${currency.symbol} ' : null;
    final suffixSymbol = currency.symbolBefore ? null : currency.symbol;
    final ocrTotal = _ocrGrandTotal;
    final diff = ocrTotal == null ? null : _computedGrandTotal - ocrTotal;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingBill == null ? s.inputBillTitle : s.editBillTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
        children: [
          if (widget.onOpenScanOcr != null) ...[
            Card(
              color: p.primarySoft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: p.primary.withValues(alpha: 0.25)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _handleScanOcr,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: p.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.document_scanner_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.scanOcrTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.scanOcrSubtitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: p.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.restaurantName,
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
                    key: const ValueKey('bill_date_picker'),
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
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('bill_input_note_field'),
                    controller: _noteCtrl,
                    decoration: InputDecoration(
                      labelText: s.noteLabel,
                      hintText: s.noteHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('bill_input_trip_field'),
                    controller: _tripCtrl,
                    decoration: InputDecoration(
                      labelText: s.tripLabel,
                      hintText: s.tripHint,
                      prefixIcon: Icon(
                        Icons.luggage_outlined,
                        size: 18,
                        color: p.muted,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (widget.controller.activeTripNames.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final trip in widget.controller.activeTripNames)
                          ActionChip(
                            avatar: const Icon(Icons.luggage_outlined, size: 15),
                            label: Text(trip),
                            onPressed: () {
                              _tripCtrl.text = trip;
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.itemsList,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                s.subtotalText(formatMoney(_itemsSubtotal, currency: currency)),
                style: kTabularStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rows[i].nameCtrl,
                              decoration: InputDecoration(
                                hintText: s.itemHint(i + 1),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_rows.length > 1)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _removeRow(i),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: p.muted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: 68,
                            child: TextField(
                              controller: _rows[i].qtyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [qtyFormatter],
                              decoration: InputDecoration(labelText: s.qtyLabel),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _rows[i].unitPriceCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [amountFormatter],
                              style: kTabularStyle,
                              decoration: InputDecoration(
                                labelText: s.unitPriceLabel,
                                prefixText: prefixSymbol,
                                suffixText: suffixSymbol,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      if (_rows[i].parsedQty != 1 &&
                          _rows[i].parsedUnitPrice > 0) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            s.lineTotalInline(
                              formatMoney(
                                _rows[i].computedLineTotal,
                                currency: currency,
                              ),
                            ),
                            style: kTabularStyle.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: p.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(s.addItemBtn),
          ),
          const SizedBox(height: 18),
          Text(
            s.feesAndDiscounts,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taxCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [amountFormatter],
                          style: kTabularStyle,
                          decoration: InputDecoration(
                            labelText: s.vatLabelCurrency(currency.code),
                            prefixText: prefixSymbol,
                            suffixText: suffixSymbol,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('+8%'),
                        onPressed: () {
                          _taxCtrl.text =
                              _fmtInput((_itemsSubtotal * 0.08).round());
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 4),
                      ActionChip(
                        label: const Text('+10%'),
                        onPressed: () {
                          _taxCtrl.text =
                              _fmtInput((_itemsSubtotal * 0.10).round());
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serviceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [amountFormatter],
                          style: kTabularStyle,
                          decoration: InputDecoration(
                            labelText:
                                s.serviceChargeLabelCurrency(currency.code),
                            prefixText: prefixSymbol,
                            suffixText: suffixSymbol,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('+5%'),
                        onPressed: () {
                          _serviceCtrl.text =
                              _fmtInput((_itemsSubtotal * 0.05).round());
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _shipCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [amountFormatter],
                          style: kTabularStyle,
                          decoration: InputDecoration(
                            labelText: s.shippingLabelCurrency(currency.code),
                            prefixText: prefixSymbol,
                            suffixText: suffixSymbol,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<ShippingSplitMode>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: ShippingSplitMode.flat,
                            label: Text(s.shipFlat),
                          ),
                          ButtonSegment(
                            value: ShippingSplitMode.proRata,
                            label: Text(s.shipProRata),
                          ),
                        ],
                        selected: {_shippingMode},
                        onSelectionChanged: (sel) =>
                            setState(() => _shippingMode = sel.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _discountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [amountFormatter],
                    style: kTabularStyle,
                    decoration: InputDecoration(
                      labelText: s.billDiscountLabelCurrency(currency.code),
                      prefixText: prefixSymbol,
                      suffixText: suffixSymbol,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ocrTotalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [amountFormatter],
                    style: kTabularStyle,
                    decoration: InputDecoration(
                      labelText: s.ocrTotalLabel,
                      prefixText: prefixSymbol,
                      suffixText: suffixSymbol,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (diff != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: diff == 0 ? p.successSoft : p.dangerSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        diff == 0
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: diff == 0 ? p.success : p.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          diff == 0
                              ? s.ocrMatched(
                                  formatMoney(ocrTotal!, currency: currency),
                                )
                              : s.ocrMismatch(
                                  formatSignedMoney(diff, currency: currency),
                                  formatMoney(ocrTotal!, currency: currency),
                                ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: diff == 0 ? p.success : p.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.grandTotal,
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                        Text(
                          formatMoney(_computedGrandTotal, currency: currency),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: kTabularStyle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: p.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _goToAssign,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(s.nextAssign),
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

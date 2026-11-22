import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../models/bill_models.dart';
import '../theme/mam_theme.dart';
import '../state/mam_controller.dart';
import 'split_assign_screen.dart';

class _EditableItemRow {
  _EditableItemRow({
    required this.id,
    String name = '',
    double quantity = 1,
    int lineTotal = 0,
    int itemDiscount = 0,
    Map<String, double>? shares,
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: formatQty(quantity)),
        totalCtrl = TextEditingController(
          text: lineTotal > 0 ? lineTotal.toString() : '',
        ),
        discountCtrl = TextEditingController(
          text: itemDiscount > 0 ? itemDiscount.toString() : '',
        ),
        existingShares = shares ?? const {};

  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController totalCtrl;
  final TextEditingController discountCtrl;
  final Map<String, double> existingShares;

  BillItem toBillItem() {
    final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1;
    return BillItem(
      id: id,
      name: nameCtrl.text.trim().isEmpty ? 'Món ăn' : nameCtrl.text.trim(),
      quantity: qty > 0 ? qty : 1,
      lineTotal: parseVndInput(totalCtrl.text),
      itemDiscount: parseVndInput(discountCtrl.text),
      shares: existingShares,
    );
  }

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    totalCtrl.dispose();
    discountCtrl.dispose();
  }
}

class BillInputScreen extends StatefulWidget {
  const BillInputScreen({
    super.key,
    required this.controller,
    this.existingBill,
    this.onOpenScanOcr,
  });

  final MamController controller;
  final BillRecord? existingBill;
  final Future<OcrScanResult?> Function(BuildContext context)? onOpenScanOcr;

  @override
  State<BillInputScreen> createState() => _BillInputScreenState();
}

class _BillInputScreenState extends State<BillInputScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _serviceCtrl;
  late final TextEditingController _shipCtrl;
  late final TextEditingController _discountCtrl;
  late final TextEditingController _ocrTotalCtrl;
  late ShippingSplitMode _shippingMode;
  late DateTime _billDate;
  final List<_EditableItemRow> _rows = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    final bill = widget.existingBill;
    final adj = bill?.payload.adjustments;

    _titleCtrl = TextEditingController(text: bill?.title ?? defaultMealTitle());
    _billDate = bill?.billDate ?? DateTime.now();
    _taxCtrl = TextEditingController(
      text: (adj?.taxAmount ?? 0) > 0 ? adj!.taxAmount.toString() : '',
    );
    _serviceCtrl = TextEditingController(
      text: (adj?.serviceChargeAmount ?? 0) > 0
          ? adj!.serviceChargeAmount.toString()
          : '',
    );
    _shipCtrl = TextEditingController(
      text: (adj?.shippingAmount ?? 0) > 0 ? adj!.shippingAmount.toString() : '',
    );
    _discountCtrl = TextEditingController(
      text: (adj?.billDiscountAmount ?? 0) > 0
          ? adj!.billDiscountAmount.toString()
          : '',
    );
    _ocrTotalCtrl = TextEditingController(
      text: (adj?.ocrGrandTotal ?? 0) > 0 ? adj!.ocrGrandTotal.toString() : '',
    );
    _shippingMode =
        adj?.shippingMode ?? widget.controller.settings.defaultShippingMode;

    if (bill != null && bill.payload.items.isNotEmpty) {
      for (final item in bill.payload.items) {
        _rows.add(
          _EditableItemRow(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            lineTotal: item.lineTotal,
            itemDiscount: item.itemDiscount,
            shares: item.shares,
          ),
        );
      }
    } else {
      _rows.add(_EditableItemRow(id: 'item_1'));
      _rows.add(_EditableItemRow(id: 'item_2'));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
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
        (sum, r) => sum + r.toBillItem().netTotal,
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
    if (widget.onOpenScanOcr == null) return;
    setState(() => _scanning = true);
    try {
      final result = await widget.onOpenScanOcr!(context);
      if (result == null || !mounted) return;
      _applyOcrResult(result);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _applyOcrResult(OcrScanResult result) {
    setState(() {
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
          _EditableItemRow(
            id: 'ocr_${DateTime.now().microsecondsSinceEpoch}_$i',
            name: item.name,
            quantity: item.quantity,
            lineTotal: item.lineTotal,
            itemDiscount: item.itemDiscount,
          ),
        );
      }
      if (_rows.isEmpty) {
        _rows.add(_EditableItemRow(id: 'item_1'));
      }
      _taxCtrl.text = result.taxAmount > 0 ? result.taxAmount.toString() : '';
      _serviceCtrl.text = result.serviceChargeAmount > 0
          ? result.serviceChargeAmount.toString()
          : '';
      _shipCtrl.text =
          result.shippingAmount > 0 ? result.shippingAmount.toString() : '';
      _discountCtrl.text = result.billDiscountAmount > 0
          ? result.billDiscountAmount.toString()
          : '';
      _ocrTotalCtrl.text =
          (result.ocrGrandTotal ?? 0) > 0 ? result.ocrGrandTotal.toString() : '';
    });
  }

  void _goToAssign() {
    final items = _rows
        .map((r) => r.toBillItem())
        .where((i) => i.lineTotal > 0)
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần ít nhất 1 món có giá trị > 0đ')),
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
        ? defaultMealTitle()
        : _titleCtrl.text.trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SplitAssignScreen(
          controller: widget.controller,
          existingBill: widget.existingBill,
          title: title,
          billDate: _billDate,
          items: items,
          adjustments: adjustments,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ocrTotal = _ocrGrandTotal;
    final diff = ocrTotal == null ? null : _computedGrandTotal - ocrTotal;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingBill == null ? 'Nhập hóa đơn' : 'Sửa hóa đơn'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
        children: [
          if (widget.onOpenScanOcr != null) ...[
            Card(
              color: MamColors.accentSoft,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _scanning ? null : _handleScanOcr,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: MamColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _scanning
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.document_scanner_rounded,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scan ảnh hóa đơn (AI OCR)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: MamColors.ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Chụp bill thật hoặc thử hóa đơn mẫu VN',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: MamColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: MamColors.accent),
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
                  const Text(
                    'Tên quán / Bữa ăn',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: MamColors.muted),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(hintText: 'vd: Lẩu Haidilao'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Danh sách món',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'Tạm tính: ${formatVnd(_itemsSubtotal)}',
                style: kTabularStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MamColors.muted,
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
                                hintText: 'Tên món #${i + 1}',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_rows.length > 1)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _removeRow(i),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: MamColors.muted,
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'SL'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _rows[i].totalCtrl,
                              keyboardType: TextInputType.number,
                              style: kTabularStyle,
                              decoration: const InputDecoration(
                                labelText: 'Thành tiền',
                                suffixText: 'đ',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _rows[i].discountCtrl,
                              keyboardType: TextInputType.number,
                              style: kTabularStyle,
                              decoration: const InputDecoration(
                                labelText: 'Giảm riêng',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Thêm món'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Thuế, phụ phí & giảm giá',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                          style: kTabularStyle,
                          decoration: const InputDecoration(
                            labelText: 'VAT (VNĐ)',
                            suffixText: 'đ',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('+8%'),
                        onPressed: () {
                          _taxCtrl.text = (_itemsSubtotal * 0.08).round().toString();
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 4),
                      ActionChip(
                        label: const Text('+10%'),
                        onPressed: () {
                          _taxCtrl.text = (_itemsSubtotal * 0.10).round().toString();
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
                          style: kTabularStyle,
                          decoration: const InputDecoration(
                            labelText: 'Phí phục vụ (VNĐ)',
                            suffixText: 'đ',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('+5%'),
                        onPressed: () {
                          _serviceCtrl.text = (_itemsSubtotal * 0.05).round().toString();
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
                          style: kTabularStyle,
                          decoration: const InputDecoration(
                            labelText: 'Tiền ship (VNĐ)',
                            suffixText: 'đ',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<ShippingSplitMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: ShippingSplitMode.flat, label: Text('Đều')),
                          ButtonSegment(value: ShippingSplitMode.proRata, label: Text('Tỷ lệ')),
                        ],
                        selected: {_shippingMode},
                        onSelectionChanged: (s) => setState(() => _shippingMode = s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _discountCtrl,
                    keyboardType: TextInputType.number,
                    style: kTabularStyle,
                    decoration: const InputDecoration(
                      labelText: 'Giảm giá / Voucher toàn bill (VNĐ)',
                      suffixText: 'đ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ocrTotalCtrl,
                    keyboardType: TextInputType.number,
                    style: kTabularStyle,
                    decoration: const InputDecoration(
                      labelText: 'Tổng in trên bill để đối chiếu (không bắt buộc)',
                      suffixText: 'đ',
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
          decoration: const BoxDecoration(
            color: MamColors.paper,
            border: Border(top: BorderSide(color: MamColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (diff != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: diff == 0 ? MamColors.sageSoft : MamColors.dangerSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        diff == 0
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: diff == 0 ? MamColors.sage : MamColors.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          diff == 0
                              ? 'Khớp tổng in trên bill (${formatVnd(ocrTotal!)})'
                              : 'Lệch ${formatSignedVnd(diff)} so với tổng bill (${formatVnd(ocrTotal!)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: diff == 0 ? MamColors.sage : MamColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng cộng',
                        style: TextStyle(fontSize: 12, color: MamColors.muted),
                      ),
                      Text(
                        formatVnd(_computedGrandTotal),
                        style: kTabularStyle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _goToAssign,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Tiếp: Gán món'),
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

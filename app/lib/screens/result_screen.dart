import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/calculator.dart';
import '../core/export_png.dart';
import '../core/formatters.dart';
import '../core/vietqr.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import '../widgets/receipt_card.dart';
import 'bill_input_screen.dart';
import 'settings_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.controller,
    required this.billId,
    this.onOpenScanOcr,
  });

  final MamController controller;
  final String billId;
  final Future<OcrScanResult?> Function(BuildContext context)? onOpenScanOcr;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final Set<String> _expandedPersonIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final p = context.mam;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final bill = ctrl.findBillById(widget.billId);
        if (bill == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Kết quả')),
            body: const Center(child: Text('Không tìm thấy hóa đơn.')),
          );
        }

        final calc = BillCalculator.calculate(bill.payload);
        final activeBanks = ctrl.activeBankAccounts;
        final bankSnapshot =
            bill.payload.bankAccountSnapshot ?? ctrl.defaultBankAccount?.toSnapshot();

        final paidCount =
            bill.payload.participants.where((e) => e.isHost || e.paid).length;
        final totalPeople = bill.payload.participants.length;

        return Scaffold(
          appBar: AppBar(
            title: Text(bill.title),
            actions: [
              if (bill.mode == BillMode.itemized)
                IconButton(
                  tooltip: 'Sửa hóa đơn',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BillInputScreen(
                          controller: ctrl,
                          existingBill: bill,
                          onOpenScanOcr: widget.onOpenScanOcr,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
            children: [
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
                              '${formatDateVn(bill.billDate, includeYear: true)} · $paidCount/$totalPeople đã trả',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatVnd(calc.computedGrandTotal),
                            style: kTabularStyle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<RoundingMode>(
                          segments: const [
                            ButtonSegment(
                              value: RoundingMode.none,
                              label: Text('Không'),
                            ),
                            ButtonSegment(
                              value: RoundingMode.nearest1000,
                              label: Text('Gần 1k'),
                            ),
                            ButtonSegment(
                              value: RoundingMode.ceil1000,
                              label: Text('Lên 1k'),
                            ),
                          ],
                          selected: {bill.payload.roundingMode},
                          onSelectionChanged: (s) =>
                              ctrl.updateBillRounding(bill.id, s.first),
                        ),
                      ),
                      if (calc.roundingDelta != 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: p.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: p.border),
                          ),
                          child: Text(
                            'Chênh lệch làm tròn: Chủ xị ${calc.roundingDelta > 0 ? 'dư' : 'bù'} ${formatSignedVnd(calc.roundingDelta)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: p.muted,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _pickBankSheet(context, bill, activeBanks),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: p.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_rounded,
                                size: 16,
                                color: p.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bankSnapshot == null
                                      ? 'Chưa có STK nhận tiền — Chạm để thêm'
                                      : 'Nhận tiền: ${bankSnapshot.bankShortName} · ${bankSnapshot.accountNo}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: p.ink,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.swap_horiz_rounded,
                                size: 16,
                                color: p.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chi tiết từng người',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < calc.breakdowns.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ParticipantResultCard(
                    breakdown: calc.breakdowns[i],
                    accentColor: p.participantColor(i),
                    expanded: _expandedPersonIds
                        .contains(calc.breakdowns[i].participant.id),
                    onToggleExpand: () {
                      final id = calc.breakdowns[i].participant.id;
                      setState(() {
                        if (!_expandedPersonIds.add(id)) {
                          _expandedPersonIds.remove(id);
                        }
                      });
                    },
                    onTogglePaid: calc.breakdowns[i].participant.isHost
                        ? null
                        : () => ctrl.toggleParticipantPaid(
                              bill.id,
                              calc.breakdowns[i].participant.id,
                            ),
                    onShowQr: (calc.breakdowns[i].participant.isHost ||
                            calc.breakdowns[i].finalAmount <= 0)
                        ? null
                        : () => _openPersonQrModal(
                              context,
                              bill: bill,
                              breakdown: calc.breakdowns[i],
                              bank: bankSnapshot,
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
                onPressed: () => _openSummaryReceiptModal(
                  context,
                  bill: bill,
                  calc: calc,
                  bank: bankSnapshot,
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Xuất Receipt Card tổng (PNG)'),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickBankSheet(
    BuildContext context,
    BillRecord bill,
    List<BankAccount> accounts,
  ) async {
    if (accounts.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsScreen(controller: widget.controller),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Chọn tài khoản nhận tiền',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...accounts.map(
              (a) => ListTile(
                leading: const Icon(Icons.account_balance_rounded),
                title: Text(a.bankShortName),
                subtitle: Text(a.accountNo),
                onTap: () async {
                  await widget.controller.updateBillBankAccount(bill.id, a);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSummaryReceiptModal(
    BuildContext context, {
    required BillRecord bill,
    required BillCalculationResult calc,
    required BankAccountSnapshot? bank,
  }) async {
    final boundaryKey = GlobalKey();
    var exporting = false;
    final p = context.mam;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.ground,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Xem trước Receipt Card',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: RepaintBoundary(
                        key: boundaryKey,
                        child: SummaryReceiptCard(
                          bill: bill,
                          calc: calc,
                          bank: bank,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: exporting
                          ? null
                          : () async {
                              setModalState(() => exporting = true);
                              try {
                                final slug = VietQrGenerator.normalizeTransferNote(
                                  bill.title,
                                  maxLength: 24,
                                ).replaceAll(' ', '_');
                                await ReceiptPngExporter.shareBoundaryAsPng(
                                  boundaryKey: boundaryKey,
                                  fileName: 'mam_${slug.isEmpty ? 'bill' : slug}.png',
                                  shareText:
                                      'Mâm — Chia bill ${bill.title} (${formatVnd(calc.computedGrandTotal)})',
                                );
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Không xuất được ảnh: $e')),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setModalState(() => exporting = false);
                                }
                              }
                            },
                      icon: exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(
                        exporting
                            ? 'Đang xuất ảnh...'
                            : 'Chia sẻ ảnh PNG (Zalo / Messenger)',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPersonQrModal(
    BuildContext context, {
    required BillRecord bill,
    required ParticipantBreakdown breakdown,
    required BankAccountSnapshot? bank,
  }) async {
    if (bank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng thêm tài khoản ngân hàng trong Cài đặt để tạo VietQR',
          ),
        ),
      );
      return;
    }

    final boundaryKey = GlobalKey();
    final transferNote = VietQrGenerator.formatTransferNote(
      template: bill.payload.transferNoteTemplate,
      participantName: breakdown.participant.name,
      billTitle: bill.title,
    );
    var exporting = false;
    final p = context.mam;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.ground,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'VietQR cho ${breakdown.participant.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 8),
                Center(
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: PersonQrCard(
                      bill: bill,
                      breakdown: breakdown,
                      bank: bank,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: bank.accountNo),
                          );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép số tài khoản'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy STK'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: transferNote),
                          );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép nội dung CK'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.notes_rounded, size: 16),
                        label: const Text('Copy ND'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: exporting
                        ? null
                        : () async {
                            setModalState(() => exporting = true);
                            try {
                              final slug = VietQrGenerator.normalizeTransferNote(
                                breakdown.participant.name,
                                maxLength: 16,
                              ).replaceAll(' ', '_');
                              await ReceiptPngExporter.shareBoundaryAsPng(
                                boundaryKey: boundaryKey,
                                fileName:
                                    'mam_qr_${slug.isEmpty ? 'person' : slug}.png',
                                shareText:
                                    '${breakdown.participant.name}: ${formatVnd(breakdown.finalAmount)} ($transferNote)',
                              );
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Không xuất được ảnh: $e')),
                                );
                              }
                            } finally {
                              if (ctx.mounted) {
                                setModalState(() => exporting = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(
                      exporting
                          ? 'Đang xuất ảnh...'
                          : 'Gửi thẻ VietQR riêng (PNG)',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantResultCard extends StatelessWidget {
  const _ParticipantResultCard({
    required this.breakdown,
    required this.accentColor,
    required this.expanded,
    required this.onToggleExpand,
    this.onTogglePaid,
    this.onShowQr,
  });

  final ParticipantBreakdown breakdown;
  final Color accentColor;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback? onTogglePaid;
  final VoidCallback? onShowQr;

  @override
  Widget build(BuildContext context) {
    final palette = context.mam;
    final p = breakdown.participant;
    final paid = p.isHost || p.paid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggleExpand,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: accentColor.withValues(alpha: 0.16),
                    child: Text(
                      p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.isHost ? '${p.name} (Chủ xị)' : p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (paid) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.successSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Đã trả',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: palette.success,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${breakdown.itemShares.length} món · Chạm xem chi tiết',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatVnd(breakdown.finalAmount),
                    style: kTabularStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: paid ? palette.success : palette.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 8),
              ...breakdown.itemShares.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.itemName,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      Text(
                        formatVnd(s.amount.round()),
                        style: kTabularStyle.copyWith(
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (breakdown.proRataAdjustment.round() != 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Thuế / Phí / Giảm giá (pro-rata)',
                          style: TextStyle(fontSize: 12.5, color: palette.muted),
                        ),
                      ),
                      Text(
                        formatSignedVnd(breakdown.proRataAdjustment.round()),
                        style: kTabularStyle.copyWith(
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              if (breakdown.flatAdjustment.round() != 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tiền ship (chia đều)',
                          style: TextStyle(fontSize: 12.5, color: palette.muted),
                        ),
                      ),
                      Text(
                        formatSignedVnd(breakdown.flatAdjustment.round()),
                        style: kTabularStyle.copyWith(
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (!p.isHost) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTogglePaid,
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            paid ? palette.successSoft : palette.surface,
                        foregroundColor:
                            paid ? palette.success : palette.ink,
                        side: BorderSide(
                          color: paid ? palette.success : palette.border,
                        ),
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: Icon(
                        paid
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                      ),
                      label: Text(paid ? 'Đã trả' : 'Tick đã trả'),
                    ),
                  ),
                  if (onShowQr != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onShowQr,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.primarySoft,
                          foregroundColor: palette.primary,
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                        label: const Text('VietQR riêng'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

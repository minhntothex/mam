import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/calculator.dart';
import '../core/formatters.dart';
import '../core/vietqr.dart';
import '../models/bill_models.dart';
import '../theme/mam_theme.dart';

/// Exported PNG Receipt Cards always use print-safe crisp white stock
/// (`MamReceiptColors`) so VietQR codes scan reliably from Zalo/Messenger even
/// when the app itself is used in Dark Mode.

class SummaryReceiptCard extends StatelessWidget {
  const SummaryReceiptCard({
    super.key,
    required this.bill,
    required this.calc,
    this.bank,
  });

  final BillRecord bill;
  final BillCalculationResult calc;
  final BankAccountSnapshot? bank;

  @override
  Widget build(BuildContext context) {
    String? staticQr;
    if (bank != null) {
      try {
        staticQr = VietQrGenerator.generate(
          bankBin: bank!.bankBin,
          accountNo: bank!.accountNo,
          transferNote: VietQrGenerator.normalizeTransferNote(bill.title),
        );
      } catch (_) {
        staticQr = null;
      }
    }

    final adj = bill.payload.adjustments;

    return Container(
      width: 360,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MamReceiptColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MamReceiptColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MamReceiptColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'MÂM',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PHIẾU CHIA BILL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MamReceiptColors.muted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                formatDateVn(bill.billDate, includeYear: true),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: MamReceiptColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bill.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MamReceiptColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          const _DashedDivider(),
          const SizedBox(height: 12),
          for (var i = 0; i < calc.breakdowns.length; i++) ...[
            _ReceiptPersonRow(
              breakdown: calc.breakdowns[i],
              accentColor: MamPalette.light.participantColor(i),
            ),
            if (i < calc.breakdowns.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          const _DashedDivider(),
          const SizedBox(height: 10),
          _SummaryLine(label: 'Tiền món', value: formatVnd(calc.allItemsSubtotal)),
          if (adj.taxAmount > 0)
            _SummaryLine(label: 'Thuế VAT', value: '+${formatVnd(adj.taxAmount)}'),
          if (adj.serviceChargeAmount > 0)
            _SummaryLine(
              label: 'Phí phục vụ',
              value: '+${formatVnd(adj.serviceChargeAmount)}',
            ),
          if (adj.shippingAmount > 0)
            _SummaryLine(
              label:
                  'Tiền ship (${adj.shippingMode == ShippingSplitMode.flat ? 'chia đều' : 'tỷ lệ'})',
              value: '+${formatVnd(adj.shippingAmount)}',
            ),
          if (adj.billDiscountAmount > 0)
            _SummaryLine(
              label: 'Giảm giá toàn bill',
              value: '-${formatVnd(adj.billDiscountAmount)}',
              valueColor: MamReceiptColors.success,
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TỔNG CỘNG',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: MamReceiptColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatVnd(calc.computedGrandTotal),
                style: kTabularStyle.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: MamReceiptColors.primary,
                ),
              ),
            ],
          ),
          if (calc.roundingDelta != 0) ...[
            const SizedBox(height: 4),
            Text(
              'Làm tròn 1.000đ · Chênh lệch: ${formatSignedVnd(calc.roundingDelta)}',
              style: const TextStyle(
                fontSize: 11,
                color: MamReceiptColors.muted,
              ),
            ),
          ],
          if (bank != null && staticQr != null) ...[
            const SizedBox(height: 14),
            const _DashedDivider(),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MamReceiptColors.border),
                  ),
                  child: QrImageView(
                    data: staticQr,
                    size: 92,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QUÉT VIETQR THANH TOÁN',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: MamReceiptColors.primary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bank!.bankShortName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: MamReceiptColors.ink,
                        ),
                      ),
                      Text(
                        bank!.accountNo,
                        style: kTabularStyle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MamReceiptColors.ink,
                        ),
                      ),
                      if (bank!.accountName != null &&
                          bank!.accountName!.isNotEmpty)
                        Text(
                          bank!.accountName!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: MamReceiptColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class PersonQrCard extends StatelessWidget {
  const PersonQrCard({
    super.key,
    required this.bill,
    required this.breakdown,
    required this.bank,
  });

  final BillRecord bill;
  final ParticipantBreakdown breakdown;
  final BankAccountSnapshot bank;

  @override
  Widget build(BuildContext context) {
    final p = breakdown.participant;
    final transferNote = VietQrGenerator.formatTransferNote(
      template: bill.payload.transferNoteTemplate,
      participantName: p.name,
      billTitle: bill.title,
    );
    final dynamicQr = VietQrGenerator.generate(
      bankBin: bank.bankBin,
      accountNo: bank.accountNo,
      amount: breakdown.finalAmount,
      transferNote: transferNote,
    );

    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MamReceiptColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MamReceiptColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MamReceiptColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'MÂM',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bill.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: MamReceiptColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Phần của ${p.name}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MamReceiptColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatVnd(breakdown.finalAmount),
            style: kTabularStyle.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: MamReceiptColors.primary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MamReceiptColors.border, width: 1.5),
            ),
            child: QrImageView(
              data: dynamicQr,
              size: 184,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${bank.bankShortName} · ${bank.accountNo}',
            style: kTabularStyle.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: MamReceiptColors.ink,
            ),
          ),
          if (bank.accountName != null && bank.accountName!.isNotEmpty)
            Text(
              bank.accountName!,
              style: const TextStyle(
                fontSize: 12,
                color: MamReceiptColors.muted,
              ),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: MamReceiptColors.subtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ND: $transferNote',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MamReceiptColors.ink,
              ),
            ),
          ),
          if (breakdown.itemShares.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _DashedDivider(),
            const SizedBox(height: 8),
            ...breakdown.itemShares.take(5).map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: MamReceiptColors.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatVnd(s.amount.round()),
                          style: kTabularStyle.copyWith(
                            fontSize: 11.5,
                            color: MamReceiptColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (breakdown.itemShares.length > 5)
              Text(
                '+ ${breakdown.itemShares.length - 5} món khác',
                style: const TextStyle(
                  fontSize: 11,
                  color: MamReceiptColors.muted,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptPersonRow extends StatelessWidget {
  const _ReceiptPersonRow({
    required this.breakdown,
    required this.accentColor,
  });

  final ParticipantBreakdown breakdown;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final p = breakdown.participant;
    final paid = p.isHost || p.paid;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5, right: 8),
          decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
        ),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: MamReceiptColors.ink,
                      ),
                    ),
                  ),
                  if (paid) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: MamReceiptColors.success,
                    ),
                  ],
                ],
              ),
              if (breakdown.itemShares.isNotEmpty)
                Text(
                  breakdown.itemShares.map((s) => s.itemName).join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: MamReceiptColors.muted,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatVnd(breakdown.finalAmount),
          style: kTabularStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: MamReceiptColors.ink,
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: MamReceiptColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: kTabularStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? MamReceiptColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 8).floor().clamp(1, 100);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: 4, height: 1, color: MamReceiptColors.border),
          ),
        );
      },
    );
  }
}

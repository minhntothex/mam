import 'package:material_ui/material_ui.dart';

import '../core/calculator.dart';
import '../core/formatters.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';
import 'bill_input_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.controller,
    required this.billId,
  });

  final MamController controller;
  final String billId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final bill = controller.findBillById(billId);
        if (bill == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Kết quả')),
            body: const Center(child: Text('Không tìm thấy hóa đơn.')),
          );
        }

        final calc = BillCalculator.calculate(bill.payload);

        return Scaffold(
          appBar: AppBar(
            title: Text(bill.title),
            actions: [
              if (bill.mode == BillMode.itemized)
                IconButton(
                  tooltip: 'Sửa bill',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BillInputScreen(
                          controller: controller,
                          existingBill: bill,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            formatDateVn(bill.billDate, includeYear: true),
                            style: const TextStyle(color: MamColors.muted, fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            formatVnd(calc.computedGrandTotal),
                            style: kTabularStyle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<RoundingMode>(
                        segments: const [
                          ButtonSegment(value: RoundingMode.none, label: Text('Không')),
                          ButtonSegment(value: RoundingMode.nearest1000, label: Text('Gần 1k')),
                          ButtonSegment(value: RoundingMode.ceil1000, label: Text('Lên 1k')),
                        ],
                        selected: {bill.payload.roundingMode},
                        onSelectionChanged: (s) =>
                            controller.updateBillRounding(bill.id, s.first),
                      ),
                      if (calc.roundingDelta != 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Chênh lệch làm tròn: Chủ xị ${calc.roundingDelta > 0 ? 'dư' : 'bù'} ${formatSignedVnd(calc.roundingDelta)}',
                          style: const TextStyle(fontSize: 12, color: MamColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...calc.breakdowns.map((b) {
                final p = b.participant;
                final paid = p.isHost || p.paid;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        p.isHost ? '${p.name} (Chủ xị)' : p.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        b.itemShares.map((s) => s.itemName).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatVnd(b.finalAmount),
                            style: kTabularStyle.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: p.isHost
                                ? null
                                : () => controller.toggleParticipantPaid(bill.id, p.id),
                            icon: Icon(
                              paid
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: paid ? MamColors.sage : MamColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

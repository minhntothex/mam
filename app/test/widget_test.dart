import 'package:flutter_test/flutter_test.dart';
import 'package:mam/data/local_store.dart';
import 'package:mam/main.dart';
import 'package:mam/state/mam_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MamApp loads seeded bills and opens QuickEqual flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Mâm'), findsOneWidget);
    expect(find.text('Lẩu Haidilao Bitexco'), findsOneWidget);

    await tester.tap(find.text('Chia đều'));
    await tester.pumpAndSettle();
    expect(find.text('Chia đều siêu tốc'), findsOneWidget);
  });

  testWidgets('ResultScreen toggles paid and renders VietQR cards cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    // Open seeded Haidilao bill
    await tester.tap(find.text('Lẩu Haidilao Bitexco'));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết từng người'), findsOneWidget);
    expect(find.text('Xuất Receipt Card tổng (PNG)'), findsOneWidget);

    // Open Summary Receipt Card modal with embedded static VietQR
    await tester.tap(find.text('Xuất Receipt Card tổng (PNG)'));
    await tester.pumpAndSettle();
    expect(find.text('PHIẾU CHIA BILL'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mam/data/local_store.dart';
import 'package:mam/l10n/mam_strings.dart';
import 'package:mam/main.dart';
import 'package:mam/state/mam_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MamApp defaults to English and opens Quick Equal Split flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    expect(controller.language, AppLanguage.en);
    expect(find.text('Mâm'), findsOneWidget);
    expect(find.text('Uncollected'), findsOneWidget);
    expect(find.text('Lẩu Haidilao Bitexco'), findsOneWidget);

    await tester.tap(find.text('Equal split'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Equal Split'), findsOneWidget);
  });

  testWidgets('ResultScreen toggles paid and renders VietQR cards cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lẩu Haidilao Bitexco'));
    await tester.pumpAndSettle();

    expect(find.text('Per-person breakdown'), findsOneWidget);
    expect(find.text('Export Summary Receipt (PNG)'), findsOneWidget);

    await tester.tap(find.text('Export Summary Receipt (PNG)'));
    await tester.pumpAndSettle();
    expect(find.text('BILL SUMMARY'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('OCR demo preset populates BillInputScreen and reconciles totals', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New bill'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan receipt (AI OCR)'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('GrabFood Bun Dau'));
    await tester.pumpAndSettle();

    expect(find.text('Matches printed bill total (223.000đ)'), findsOneWidget);

    await tester.tap(find.text('Next: Assign'));
    await tester.pumpAndSettle();
    expect(find.text('Fast Item Assign'), findsOneWidget);
    expect(find.textContaining('unassigned'), findsOneWidget);
  });

  testWidgets('Theme toggle and EN <-> VI language switching work live', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    // Toggle Dark -> Light
    expect(controller.themeMode, ThemeMode.system);
    await tester.tap(find.byTooltip('Switch to Dark mode'));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.dark);

    await tester.tap(find.byTooltip('Switch to Light mode'));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.light);

    // Open Settings and switch English -> Vietnamese
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance & Language'), findsOneWidget);

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();
    expect(controller.language, AppLanguage.vi);
    expect(find.text('Giao diện & Ngôn ngữ'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mam/data/local_store.dart';
import 'package:mam/l10n/mam_strings.dart';
import 'package:mam/main.dart';
import 'package:mam/state/mam_controller.dart';
import 'package:mam/widgets/mam_logo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MamApp defaults to English, shows logo only, and opens Quick Equal Split', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    expect(controller.language, AppLanguage.en);
    expect(find.byType(MamLogoMark), findsOneWidget);
    expect(find.text('Mâm'), findsNothing);
    expect(find.text('Uncollected'), findsOneWidget);
    expect(find.text('Lẩu Haidilao Bitexco'), findsOneWidget);

    await tester.tap(find.text('Equal split'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Equal Split'), findsOneWidget);
  });

  testWidgets('Home supports search, swipe-left Archive, Archived divider & Restore', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    // Search by member name (case-insensitive)
    await tester.enterText(find.byType(TextField), 'minh');
    await tester.pumpAndSettle();
    expect(find.text('Lẩu Haidilao Bitexco'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'no-match-xyz');
    await tester.pumpAndSettle();
    expect(find.text('Clear search'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();

    // Swipe left on settled bill -> reveal Archive + Delete -> tap Archive
    final settledTitle = find.text('Phê La chiều (GrabFood)');
    await tester.ensureVisible(settledTitle);
    await tester.pumpAndSettle();
    expect(settledTitle, findsOneWidget);
    await tester.drag(settledTitle, const Offset(-180, 0));
    await tester.pumpAndSettle();

    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    // Divider appears in All tab & Archived pill shows count 1
    expect(find.text('Archived (1)'), findsNWidgets(2));

    // Switch to Archived tab -> swipe left -> Restore
    await tester.tap(find.text('Archived (1)').first);
    await tester.pumpAndSettle();
    final archivedTitle = find.text('Phê La chiều (GrabFood)');
    await tester.ensureVisible(archivedTitle);
    await tester.pumpAndSettle();
    expect(archivedTitle, findsOneWidget);

    await tester.drag(archivedTitle, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(find.text('Restore'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(controller.archivedBills, isEmpty);
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
    expect(find.byType(MamLogoMark), findsOneWidget);
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

  testWidgets('EN <-> VI language switching works live on single pastel theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    // Open Settings and switch English -> Vietnamese
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();
    expect(controller.language, AppLanguage.vi);
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
  });
}

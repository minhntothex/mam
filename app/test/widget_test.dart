import 'package:flutter_test/flutter_test.dart';
import 'package:mam/core/currency.dart';
import 'package:mam/data/local_store.dart';
import 'package:mam/l10n/mam_strings.dart';
import 'package:mam/main.dart';
import 'package:mam/state/mam_controller.dart';
import 'package:mam/widgets/mam_logo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MamApp shows Logo + Search in AppBar, opens Drawer panel, and opens Quick Equal Split', (tester) async {
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

    // Searchbar sits in AppBar next to logo; Local & Settings live inside Logo panel
    expect(find.descendant(of: find.byType(AppBar), matching: find.byType(TextField)), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Local')), findsNothing);

    await tester.tap(find.byType(MamLogoMark));
    await tester.pumpAndSettle();
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Close drawer and enter Quick Equal Split to verify numeric-only live formatting
    Navigator.of(tester.element(find.text('Settings'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Equal split'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Equal Split'), findsOneWidget);

    // Typing letters + digits into total field rejects letters and formats 5923892 -> 5.923.892
    final totalField = find.byType(TextField).at(1);
    await tester.enterText(totalField, 'abc5923892xyz');
    await tester.pumpAndSettle();
    expect(find.text('5.923.892'), findsOneWidget);
  });

  testWidgets('Home supports AppBar search, swipe-left Archive, Archived divider & Restore', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'minh');
    await tester.pumpAndSettle();
    expect(find.text('Lẩu Haidilao Bitexco'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'no-match-xyz');
    await tester.pumpAndSettle();
    expect(find.text('Clear search'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();

    final settledTitle = find.text('Phê La chiều (GrabFood)');
    await tester.ensureVisible(settledTitle);
    await tester.pumpAndSettle();
    await tester.drag(settledTitle, const Offset(-180, 0));
    await tester.pumpAndSettle();

    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Archived (1)'), findsNWidgets(2));

    final archivedTab = find.text('Archived (1)').first;
    await tester.ensureVisible(archivedTab);
    await tester.pumpAndSettle();
    await tester.tap(archivedTab);
    await tester.pumpAndSettle();

    final archivedTitle = find.text('Phê La chiều (GrabFood)');
    await tester.ensureVisible(archivedTitle);
    await tester.pumpAndSettle();
    await tester.drag(archivedTitle, const Offset(-180, 0));
    await tester.pumpAndSettle();
    expect(find.text('Restore'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(controller.archivedBills, isEmpty);
  });

  testWidgets('ResultScreen renders Home button before Export Summary Receipt and VietQR cards cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lẩu Haidilao Bitexco'));
    await tester.pumpAndSettle();

    expect(find.text('Per-person breakdown'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Export Summary Receipt (PNG)'), findsOneWidget);

    await tester.tap(find.text('Export Summary Receipt (PNG)'));
    await tester.pumpAndSettle();
    expect(find.byType(MamLogoMark), findsOneWidget);
    expect(find.text('MÂM'), findsNothing);
    expect(find.text('BILL SUMMARY'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    // Dismiss receipt sheet then tap Home button to return to HomeScreen
    Navigator.of(tester.element(find.text('BILL SUMMARY'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Uncollected'), findsOneWidget);
  });

  testWidgets('Save & view result -> Back returns to Assign without duplicating bill on re-save', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();
    final initialCount = controller.activeBills.length;

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

    await tester.tap(find.text('Split all'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save & View result'));
    await tester.pumpAndSettle();
    expect(find.text('Per-person breakdown'), findsOneWidget);
    expect(controller.activeBills.length, initialCount + 1);

    // Press Back -> returns to Assign screen (NOT Home!)
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Fast Item Assign'), findsOneWidget);

    // Re-save -> updates same bill without creating a duplicate
    await tester.tap(find.text('Save & View result'));
    await tester.pumpAndSettle();
    expect(find.text('Per-person breakdown'), findsOneWidget);
    expect(controller.activeBills.length, initialCount + 1);

    // Tap Home button -> pops straight back to HomeScreen
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Uncollected'), findsOneWidget);
  });

  testWidgets('Logo panel -> Settings switches Currency (VND <-> USD), Amount Format, and EN <-> VI', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    // Open Logo drawer -> Settings
    await tester.tap(find.byType(MamLogoMark));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Currency & Number Format'), findsOneWidget);
    expect(find.textContaining('Nearest'), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(controller.currentCurrency.code, 'VND');

    // Switch currency to USD
    await tester.tap(find.text(r'$ / USD'));
    await tester.pumpAndSettle();
    expect(controller.currentCurrency.code, 'USD');
    expect(controller.amountInputFormat, AmountInputFormat.auto);

    // Open Transfer note template dialog and verify helper text allows multi-line (not truncated)
    final templateItem = find.text('Transfer note template');
    await tester.scrollUntilVisible(
      templateItem,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(templateItem);
    await tester.pumpAndSettle();
    await tester.tap(templateItem);
    await tester.pumpAndSettle();
    final helperField = tester.widget<TextField>(find.byType(TextField).last);
    expect(helperField.decoration?.helperMaxLines, greaterThanOrEqualTo(3));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Scroll back up and switch language English -> Vietnamese
    final viOption = find.text('Tiếng Việt');
    await tester.scrollUntilVisible(
      viOption,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(viOption);
    await tester.pumpAndSettle();
    await tester.tap(viOption);
    await tester.pumpAndSettle();
    expect(controller.language, AppLanguage.vi);
    expect(find.text('Tiền tệ & Định dạng số'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mam/core/currency.dart';
import 'package:mam/data/local_store.dart';
import 'package:mam/l10n/mam_strings.dart';
import 'package:mam/main.dart';
import 'package:mam/models/bill_models.dart';
import 'package:mam/state/mam_controller.dart';
import 'package:mam/widgets/mam_logo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Clean production start has zero mock data and purges legacy demo records while keeping user bills', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    expect(controller.activeBills, isEmpty);
    expect(controller.activeBankAccounts, isEmpty);
    expect(controller.activeFriendGroups, isEmpty);

    // Simulate a device that previously seeded legacy demo records + 1 real user bill
    final legacyStore = await LocalStore.open();
    final demoSnapshot = legacyStore.buildDemoSeedForTest();
    final realNow = DateTime.now().toUtc();
    final userBill = BillRecord(
      id: '99999999-9999-4999-8999-999999999901',
      userId: LocalStore.localDemoUserId,
      title: 'Bún bò Huế thật',
      billDate: DateTime(2026, 11, 15),
      totalAmount: 150000,
      payload: const BillPayload(
        participants: [Participant(id: 'p1', name: 'Me', isHost: true, paid: true)],
        items: [BillItem(id: 'i1', name: 'Bún bò', quantity: 2, lineTotal: 150000, shares: {'p1': 1})],
      ),
      createdAt: realNow,
      updatedAt: realNow,
    );
    await legacyStore.saveAll(
      LocalDataSnapshot(
        bills: [...demoSnapshot.bills, userBill],
        bankAccounts: demoSnapshot.bankAccounts,
        friendGroups: demoSnapshot.friendGroups,
        settings: demoSnapshot.settings,
        pendingSyncKeys: <String>{},
        lastSyncedAt: null,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mam_seeded_v1', true);
    await prefs.remove('mam_cleaned_legacy_demo_v1');

    final migratedController = MamController(store: legacyStore);
    await migratedController.init();
    expect(migratedController.activeBills.map((b) => b.title), ['Bún bò Huế thật']);
    expect(migratedController.activeBankAccounts, isEmpty);
    expect(migratedController.activeFriendGroups, isEmpty);
  });

  testWidgets('MamApp shows flat Logo + Search in AppBar, equal-width bottom buttons, Drawer panel, and Quick Equal Split', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init(seedDemo: true);

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    expect(controller.language, AppLanguage.en);
    expect(find.byType(MamLogoMark), findsOneWidget);
    // Flat transparent logo (showTile: false) matches 40px search bar height on HomeScreen
    expect(tester.widget<MamLogoMark>(find.byType(MamLogoMark)).showTile, isFalse);
    expect(
      find.descendant(of: find.byType(MamLogoMark), matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    expect(tester.getSize(find.byType(MamLogoMark)), const Size(40, 40));
    expect(
      tester.getSize(
        find.descendant(of: find.byType(AppBar), matching: find.byType(TextField)),
      ).height,
      40,
    );
    expect(find.text('Mâm'), findsNothing);
    expect(find.text('Uncollected'), findsOneWidget);
    expect(find.text('Lẩu Haidilao Bitexco'), findsOneWidget);

    // Equal split and New bill buttons share identical 50/50 widths
    final equalBtnSize = tester.getSize(find.widgetWithText(OutlinedButton, 'Equal split'));
    final newBillBtnSize = tester.getSize(find.widgetWithText(FilledButton, 'New bill'));
    expect((equalBtnSize.width - newBillBtnSize.width).abs(), lessThan(1.0));

    // Searchbar sits in AppBar next to logo; Local & Settings live inside Logo panel
    expect(find.descendant(of: find.byType(AppBar), matching: find.byType(TextField)), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Local')), findsNothing);

    await tester.tap(find.byType(MamLogoMark));
    await tester.pumpAndSettle();
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Close drawer and enter Quick Equal Split to verify date picker + numeric formatting
    Navigator.of(tester.element(find.text('Settings'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Equal split'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Equal Split'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick_equal_date_picker')), findsOneWidget);

    // Quick Equal Split starts with empty title (placeholder only), subtle '0' total hint,
    // and only Me (Host) without Guest 2 / Guest 3.
    final titleField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(titleField.controller?.text, isEmpty);
    expect(titleField.decoration?.hintText, isNotEmpty);

    final totalWidget = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(totalWidget.decoration?.hintText, '0');
    expect(totalWidget.decoration?.hintStyle?.fontWeight, FontWeight.w500);

    // Typing letters + digits into total field rejects letters and formats 5923892 -> 5.923.892
    final totalField = find.byType(TextField).at(1);
    await tester.enterText(totalField, 'abc5923892xyz');
    await tester.pumpAndSettle();
    expect(find.text('5.923.892'), findsOneWidget);

    // Scroll to Participants section -> starts with only Me (Host), no Guest 2 / Guest 3, no +/- buttons
    await tester.scrollUntilVisible(
      find.text('Me (Host)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Me (Host)'), findsOneWidget);
    expect(find.text('Guest 2'), findsNothing);
    expect(find.text('Guest 3'), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNothing);
  });

  testWidgets('Home supports AppBar search, swipe-left Archive, Archived divider & Restore', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init(seedDemo: true);

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'minh');
    await tester.pumpAndSettle();
    expect(find.text('Lẩu Haidilao Bitexco'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'no-match-xyz');
    await tester.pumpAndSettle();
    expect(find.text('Clear search'), findsOneWidget);
    // Empty filter/search state renders directly on app ground without Card wrapper
    expect(
      find.ancestor(of: find.text('Clear search'), matching: find.byType(Card)),
      findsNothing,
    );

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
    await controller.init(seedDemo: true);

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lẩu Haidilao Bitexco'));
    await tester.pumpAndSettle();

    expect(find.text('Per-person breakdown'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Export Summary Receipt'), findsOneWidget);

    await tester.tap(find.text('Export Summary Receipt'));
    await tester.pumpAndSettle();
    expect(find.byType(MamLogoMark), findsOneWidget);
    expect(find.text('MÂM'), findsNothing);
    expect(find.text('BILL SUMMARY'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    Navigator.of(tester.element(find.text('BILL SUMMARY'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Uncollected'), findsOneWidget);
  });

  testWidgets('BillInputScreen supports Bill date picker, Unit price x Qty auto line total, and non-duplicating Back -> Re-save', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init(seedDemo: true);
    final initialCount = controller.activeBills.length;

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New bill'));
    await tester.pumpAndSettle();

    // New bill starts with empty Restaurant / Meal input (placeholder only)
    final restaurantField = tester.widget<TextField>(find.byType(TextField).first);
    expect(restaurantField.controller?.text, isEmpty);
    expect(restaurantField.decoration?.hintText, isNotEmpty);

    // Bill date picker sits below Restaurant / Meal
    expect(find.text('Bill date'), findsOneWidget);
    expect(find.byKey(const ValueKey('bill_date_picker')), findsOneWidget);

    // Enter Qty = 4 and Unit price = 30.000 -> auto computes Line total: 120.000đ
    final qtyField = find.widgetWithText(TextField, 'Qty').first;
    final unitPriceField = find.widgetWithText(TextField, 'Unit price').first;
    await tester.enterText(qtyField, '4');
    await tester.enterText(unitPriceField, '30000');
    await tester.pumpAndSettle();
    expect(find.text('Line total: 120.000đ'), findsOneWidget);
    expect(find.text('Subtotal: 120.000đ'), findsOneWidget);

    // Scroll back up to Scan receipt card and test OCR conversion from lineTotal -> unitPrice
    final scanCard = find.text('Scan receipt (AI OCR)');
    await tester.ensureVisible(scanCard);
    await tester.pumpAndSettle();
    await tester.tap(scanCard);
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

  testWidgets('Logo panel -> Settings switches Currency, Amount Format, EN <-> VI, and has no Reset demo button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init(seedDemo: true);

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MamLogoMark));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Currency & Number Format'), findsOneWidget);
    expect(find.textContaining('Nearest'), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.text('Reset demo sample data'), findsNothing);
    expect(controller.currentCurrency.code, 'VND');

    await tester.tap(find.text(r'$ / USD'));
    await tester.pumpAndSettle();
    expect(controller.currentCurrency.code, 'USD');
    expect(controller.amountInputFormat, AmountInputFormat.auto);

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

  testWidgets('Fast Item Assign starts with only Me (no Minh/Lan) and auto-marks 0-debt member paid', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init(); // Clean production start (0 saved groups)

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New bill'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Unit price').first, '100000');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next: Assign'));
    await tester.pumpAndSettle();

    // No hardcoded Minh / Lan
    expect(find.text('Minh'), findsNothing);
    expect(find.text('Lan'), findsNothing);
    expect(find.byKey(const ValueKey('inline_add_person_chip')), findsOneWidget);

    // Assign item to Me only, then add Alex (who owes 0đ)
    await tester.tap(find.text('Item'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('inline_add_person_chip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Alex');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save & View result'));
    await tester.pumpAndSettle();

    // Alex has 0đ debt -> auto-marked Paid, no Mark paid button, bill settled
    expect(controller.activeBills.single.paymentStatus, PaymentStatus.settled);
    expect(find.text('Paid'), findsNWidgets(2)); // Me (Host) + Alex (0đ)
    expect(find.text('Mark paid'), findsNothing);
  });

  testWidgets('After Cloud Sync (applySyncedSnapshot), Create result & Save & View result still save and navigate cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    // Simulate post-sync snapshot passing fixed-length/unmodifiable lists
    final now = DateTime.now().toUtc();
    await controller.applySyncedSnapshot(
      bills: List<BillRecord>.unmodifiable(const []),
      bankAccounts: List<BankAccount>.unmodifiable(const []),
      friendGroups: List<FriendGroup>.unmodifiable(const []),
      settings: controller.settings,
      remainingPendingKeys: Set<String>.unmodifiable(const <String>{}),
      syncedAt: now,
    );

    // Also verify saving bank & group succeeds after sync
    await controller.saveBankAccount(
      BankAccount(
        id: controller.newId(),
        userId: controller.currentUserId,
        bankBin: '970436',
        bankShortName: 'Vietcombank',
        accountNo: '999888777',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await controller.saveFriendGroup(
      FriendGroup(
        id: controller.newId(),
        userId: controller.currentUserId,
        name: 'Friends',
        members: const [GroupMember(id: 'm1', name: 'Me', isHost: true)],
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(controller.activeBankAccounts.length, 1);
    expect(controller.activeFriendGroups.length, 1);

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    // 1. Quick Equal Split -> Create result & VietQR navigates to ResultScreen
    await tester.tap(find.text('Equal split'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '200000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create result & VietQR'));
    await tester.pumpAndSettle();
    expect(find.text('Per-person breakdown'), findsOneWidget);
    expect(controller.activeBills.length, 1);

    // Return Home
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // 2. New bill -> Assign -> Save & View result navigates to ResultScreen
    await tester.tap(find.text('New bill'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Unit price').first, '150000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next: Assign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save & View result'));
    await tester.pumpAndSettle();
    expect(find.text('Per-person breakdown'), findsOneWidget);
    expect(controller.activeBills.length, 2);
  });
}

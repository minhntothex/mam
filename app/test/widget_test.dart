import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mam/data/local_store.dart';
import 'package:mam/l10n/mam_strings.dart';
import 'package:mam/main.dart';
import 'package:mam/models/bill_models.dart';
import 'package:mam/services/ocr_service.dart';
import 'package:mam/state/mam_controller.dart';
import 'package:mam/theme/mam_theme.dart';
import 'package:mam/widgets/mam_logo.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openCreateOption(WidgetTester tester, String keyValue) async {
  await tester.tap(find.byKey(const ValueKey('nav_create_btn')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(keyValue)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Clean production start has zero mock data and purges legacy demo records while keeping user bills', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    expect(controller.activeBills, isEmpty);
    expect(controller.activeBankAccounts, isEmpty);
    expect(controller.activeFriendGroups, isEmpty);
    expect(controller.activeMembers, isEmpty);

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

  testWidgets('Bottom bar has 5 items (Home, Members, +, Balances, Settings), logo has no Drawer, and + opens 3 create actions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init(seedDemo: true);

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    expect(controller.language, AppLanguage.en);
    expect(find.byType(MamLogoMark), findsOneWidget);
    expect(tester.widget<MamLogoMark>(find.byType(MamLogoMark)).showTile, isFalse);
    expect(tester.getSize(find.byType(MamLogoMark)), const Size(40, 40));

    // Bottom bar has all 5 slots (Balances replaces Sync) & banner has no View by person
    expect(find.byKey(const ValueKey('nav_home')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_members')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_create_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_balances')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_settings')), findsOneWidget);
    expect(find.text('View by person'), findsNothing);

    // Tapping logo does NOT open any sidebar Drawer
    await tester.tap(find.byType(MamLogoMark));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);

    // Tapping Balances opens per-person unsettled balances tab
    await tester.tap(find.byKey(const ValueKey('nav_balances')));
    await tester.pumpAndSettle();
    expect(find.text('Unsettled by person'), findsOneWidget);

    // Tapping + opens action sheet with Equal split, New bill, and Scan receipt
    await tester.tap(find.byKey(const ValueKey('nav_create_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create_action_equal')), findsOneWidget);
    expect(find.byKey(const ValueKey('create_action_new_bill')), findsOneWidget);
    expect(find.byKey(const ValueKey('create_action_scan')), findsOneWidget);

    // Choose Equal split -> Quick Equal Split screen
    await tester.tap(find.byKey(const ValueKey('create_action_equal')));
    await tester.pumpAndSettle();
    expect(find.text('Quick Equal Split'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick_equal_date_picker')), findsOneWidget);

    final totalField = find.byKey(const ValueKey('quick_equal_total_field'));
    await tester.enterText(totalField, 'abc5923892xyz');
    await tester.pumpAndSettle();
    expect(find.text('5.923.892'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Me (Host)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Me (Host)'), findsOneWidget);
    expect(find.text('Guest 2'), findsNothing);
    expect(find.text('Guest 3'), findsNothing);
  });

  testWidgets('Settings tab updates Currency & Language cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init(seedDemo: true);

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    await tester.pumpAndSettle();

    expect(find.text('Currency & Number Format'), findsOneWidget);
    expect(controller.currentCurrency.code, 'VND');

    await tester.tap(find.text(r'$ / USD'));
    await tester.pumpAndSettle();
    expect(controller.currentCurrency.code, 'USD');

    final viOption = find.text('Tiếng Việt');
    await tester.ensureVisible(viOption);
    await tester.pumpAndSettle();
    await tester.tap(viOption);
    await tester.pumpAndSettle();
    expect(controller.language, AppLanguage.vi);
    expect(find.text('Tiền tệ & Định dạng số'), findsOneWidget);
  });

  testWidgets('OCR Scan Sheet shows loading indicator while scanning and renders error banner inside the sheet', (tester) async {
    final completer = Completer<OcrScanResult?>();
    final ocr = OcrService(
      scanRunner: (_, _) => completer.future,
    );

    await tester.pumpWidget(
      MamStringsScope(
        strings: const MamStrings(AppLanguage.en),
        child: MaterialApp(
          theme: buildMamTheme(),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ocr.openScanSheet(ctx),
                  child: const Text('Open OCR'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open OCR'));
    await tester.pumpAndSettle();

    // Pick gallery -> immediately shows loading panel inside the sheet
    await tester.tap(find.byKey(const ValueKey('ocr_gallery_tile')));
    await tester.pump();
    expect(find.byKey(const ValueKey('ocr_loading_panel')), findsOneWidget);
    expect(find.text('Reading receipt with AI...'), findsOneWidget);

    // Fail with Gemini error -> error banner renders inside the sheet (NOT SnackBar behind it)
    completer.completeError(
      Exception('Model unavailable — please retry'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ocr_loading_panel')), findsNothing);
    expect(find.byKey(const ValueKey('ocr_error_banner')), findsOneWidget);
    expect(find.text('Could not scan receipt'), findsOneWidget);
    expect(find.textContaining('Model unavailable'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('+ -> Scan receipt launches OCR and opens pre-filled USD BillInputScreen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(
      MamApp(
        controller: controller,
        onOpenScanOcr: (_) async => OcrScanResult(
          title: 'Blue Bottle Coffee',
          billDate: DateTime(2026, 11, 24),
          currencyCode: 'USD',
          items: const [
            OcrScanItem(name: 'Latte', quantity: 2, lineTotal: 1200),
          ],
          ocrGrandTotal: 1200,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openCreateOption(tester, 'create_action_scan');
    expect(find.text('Blue Bottle Coffee'), findsOneWidget);
    expect(find.text('Matches printed bill total (\$12.00)'), findsOneWidget);
  });

  testWidgets('Home supports AppBar search, swipe-left Archive, Archived divider & Restore', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init(seedDemo: true);

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'minh');
    await tester.pumpAndSettle();
    expect(find.text('Lẩu Haidilao Bitexco'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'no-match-xyz');
    await tester.pumpAndSettle();
    expect(find.text('Clear search'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();

    final settledTitle = find.text('Phê La chiều (GrabFood)');
    await tester.ensureVisible(settledTitle);
    await tester.pumpAndSettle();
    await tester.drag(settledTitle, const Offset(-180, 0));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(controller.archivedBills, isEmpty);
  });

  testWidgets('Members Directory persists contacts, lets Quick Equal & Split Assign pick saved contacts with contactId', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    // 1. Open Members tab and add "Hải"
    await tester.tap(find.byKey(const ValueKey('nav_members')));
    await tester.pumpAndSettle();
    expect(find.text('Members'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('members_add_btn')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Hải');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(controller.activeMembers.map((m) => m.name), ['Hải']);
    expect(find.text('Hải'), findsOneWidget);

    // 2. Create Quick Equal bill: pick "Hải" from contacts chip AND add new "Trang" (auto-saved to contacts)
    await _openCreateOption(tester, 'create_action_equal');
    await tester.enterText(
      find.byKey(const ValueKey('quick_equal_total_field')),
      '300000',
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('From contacts'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Hải'));
    await tester.pumpAndSettle();

    final addPersonField = find.widgetWithText(TextField, 'Add person name...');
    await tester.ensureVisible(addPersonField);
    await tester.enterText(addPersonField, 'Trang');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
    await tester.pumpAndSettle();

    // Both "Hải" and "Trang" are now in persistent contacts directory!
    expect(
      controller.activeMembers.map((m) => m.name).toList(),
      containsAll(['Hải', 'Trang']),
    );

    await tester.tap(find.text('Create result & VietQR'));
    await tester.pumpAndSettle();

    final savedBill = controller.activeBills.single;
    final haiParticipant =
        savedBill.payload.participants.firstWhere((p) => p.name == 'Hải');
    final trangParticipant =
        savedBill.payload.participants.firstWhere((p) => p.name == 'Trang');
    expect(haiParticipant.contactId, isNotNull);
    expect(trangParticipant.contactId, isNotNull);
  });

  testWidgets('Edit Quick Equal bill (multi-payer) updates same bill with note & trip, and TripSummary + PersonLedger settle bills', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    // 1. Create a Quick Equal Multi-payer bill with Trip & Note
    await _openCreateOption(tester, 'create_action_equal');
    await tester.tap(find.text('Multiple payers'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('quick_equal_note_field')),
      'Bàn sát cửa sổ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('quick_equal_trip_field')),
      'Đà Lạt 24/11',
    );
    await tester.pumpAndSettle();

    final addNameField = find.widgetWithText(TextField, 'Add person name...');
    await tester.ensureVisible(addNameField);
    await tester.enterText(addNameField, 'Bình');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
    await tester.pumpAndSettle();

    final upfrontFields = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('upfront_'),
    );
    await tester.ensureVisible(upfrontFields.at(0));
    await tester.enterText(upfrontFields.at(0), '200000');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create result & VietQR'));
    await tester.pumpAndSettle();

    expect(controller.activeBills.length, 1);
    final originalId = controller.activeBills.single.id;
    expect(find.text('Đà Lạt 24/11'), findsOneWidget);
    expect(find.text('Bàn sát cửa sổ'), findsOneWidget);

    // 2. Tap Edit icon on ResultScreen for Quick Equal bill!
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Edit bill'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    // Update note and save -> keeps same bill ID
    await tester.enterText(
      find.byKey(const ValueKey('quick_equal_note_field')),
      'Đã cập nhật ghi chú',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(controller.activeBills.length, 1);
    expect(controller.activeBills.single.id, originalId);
    expect(find.text('Đã cập nhật ghi chú'), findsOneWidget);

    // 3. Return Home -> Home shows Trips chip "Đà Lạt 24/11" and Uncollected banner 100.000đ
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Đà Lạt 24/11'), findsOneWidget);

    // Open TripSummaryScreen from chip
    await tester.tap(find.widgetWithText(ActionChip, 'Đà Lạt 24/11'));
    await tester.pumpAndSettle();
    expect(find.text('Consolidated settlement'), findsOneWidget);
    expect(find.text('Bình'), findsOneWidget);

    // Return to Home and test Balances tab -> Mark all paid
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav_balances')));
    await tester.pumpAndSettle();
    expect(find.text('Unsettled by person'), findsOneWidget);
    expect(find.text('Mark all paid'), findsOneWidget);

    await tester.tap(find.text('Mark all paid'));
    await tester.pumpAndSettle();
    expect(controller.pendingBills, isEmpty);
  });

  testWidgets('Fast Item Assign starts with only Me, picks/adds contacts via sheet, and auto-marks 0-debt member paid', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await _openCreateOption(tester, 'create_action_new_bill');

    await tester.scrollUntilVisible(
      find.text('Items'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Unit price').first,
      '100000',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next: Assign'));
    await tester.pumpAndSettle();

    expect(find.text('Minh'), findsNothing);
    expect(find.byKey(const ValueKey('inline_add_person_chip')), findsOneWidget);

    // Assign item to Me only, then add Alex via new contacts sheet
    await tester.tap(find.text('Item'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('inline_add_person_chip')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Alex');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // Alex is also saved to persistent Members directory
    expect(controller.activeMembers.map((m) => m.name), ['Alex']);

    await tester.tap(find.text('Save & View result'));
    await tester.pumpAndSettle();

    expect(controller.activeBills.single.paymentStatus, PaymentStatus.settled);
    expect(find.text('Paid'), findsNWidgets(2));
    expect(find.text('Mark paid'), findsNothing);
  });

  testWidgets('ResultScreen renders Export Summary Receipt and VietQR cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init(seedDemo: true);

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lẩu Haidilao Bitexco'));
    await tester.pumpAndSettle();

    expect(find.text('Per-person breakdown'), findsOneWidget);
    expect(find.text('Export Summary Receipt'), findsOneWidget);

    await tester.tap(find.text('Export Summary Receipt'));
    await tester.pumpAndSettle();
    expect(find.text('BILL SUMMARY'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('After Cloud Sync (applySyncedSnapshot), Create result & Save & View result still save cleanly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final controller = MamController(store: store);
    await controller.init();

    final now = DateTime.now().toUtc();
    await controller.applySyncedSnapshot(
      bills: List<BillRecord>.unmodifiable(const []),
      bankAccounts: List<BankAccount>.unmodifiable(const []),
      friendGroups: List<FriendGroup>.unmodifiable(const []),
      members: List<MemberContact>.unmodifiable(const []),
      settings: controller.settings,
      remainingPendingKeys: Set<String>.unmodifiable(const <String>{}),
      syncedAt: now,
    );

    await controller.ensureMemberContact('Minh');
    expect(controller.activeMembers.length, 1);

    await tester.pumpWidget(MamApp(controller: controller));
    await tester.pumpAndSettle();

    await _openCreateOption(tester, 'create_action_equal');
    await tester.enterText(
      find.byKey(const ValueKey('quick_equal_total_field')),
      '200000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create result & VietQR'));
    await tester.pumpAndSettle();
    expect(find.text('Per-person breakdown'), findsOneWidget);
    expect(controller.activeBills.length, 1);
  });
}

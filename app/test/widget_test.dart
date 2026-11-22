import 'package:flutter_test/flutter_test.dart';
import 'package:mam/data/local_store.dart';
import 'package:mam/main.dart';
import 'package:mam/state/mam_controller.dart';
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
}

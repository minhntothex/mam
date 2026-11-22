import 'package:material_ui/material_ui.dart';

import 'data/local_store.dart';
import 'screens/home_screen.dart';
import 'state/mam_controller.dart';
import 'theme/mam_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  final controller = MamController(store: store);
  await controller.init();

  runApp(MamApp(controller: controller));
}

class MamApp extends StatelessWidget {
  const MamApp({super.key, required this.controller});

  final MamController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mâm',
      debugShowCheckedModeBanner: false,
      theme: buildMamTheme(),
      builder: (context, child) => MamResponsiveShell(
        child: child ?? const SizedBox.shrink(),
      ),
      home: HomeScreen(controller: controller),
    );
  }
}

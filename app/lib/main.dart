import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/local_store.dart';
import 'screens/home_screen.dart';
import 'services/supabase_config.dart';
import 'services/sync_service.dart';
import 'state/mam_controller.dart';
import 'theme/mam_theme.dart';
import 'widgets/sync_auth_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  final store = await LocalStore.open();
  final controller = MamController(store: store);
  await controller.init();

  final syncService = SyncService(controller: controller);
  syncService.attachToController();
  if (syncService.currentUser != null) {
    // Non-blocking background sync on launch
    syncService.syncAll();
  }

  runApp(
    MamApp(
      controller: controller,
      syncService: syncService,
    ),
  );
}

class MamApp extends StatelessWidget {
  const MamApp({
    super.key,
    required this.controller,
    this.syncService,
  });

  final MamController controller;
  final SyncService? syncService;

  @override
  Widget build(BuildContext context) {
    final effectiveSync = syncService ?? SyncService(controller: controller);

    return MaterialApp(
      title: 'Mâm',
      debugShowCheckedModeBanner: false,
      theme: buildMamTheme(),
      builder: (context, child) => MamResponsiveShell(
        child: child ?? const SizedBox.shrink(),
      ),
      home: HomeScreen(
        controller: controller,
        syncAuthSectionBuilder: (_) => SyncAuthCard(
          controller: controller,
          syncService: effectiveSync,
        ),
      ),
    );
  }
}

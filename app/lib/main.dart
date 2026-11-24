import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/local_store.dart';
import 'l10n/mam_strings.dart';
import 'models/bill_models.dart';
import 'screens/home_screen.dart';
import 'services/ocr_service.dart';
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
    syncService.syncAll();
  }

  runApp(
    MamApp(
      controller: controller,
      syncService: syncService,
    ),
  );
}

class MamApp extends StatefulWidget {
  const MamApp({
    super.key,
    required this.controller,
    this.syncService,
    this.onOpenScanOcr,
  });

  final MamController controller;
  final SyncService? syncService;
  final Future<OcrScanResult?> Function(BuildContext context)? onOpenScanOcr;

  @override
  State<MamApp> createState() => _MamAppState();
}

class _MamAppState extends State<MamApp> with WidgetsBindingObserver {
  static const Duration _resumeSyncCooldown = Duration(seconds: 15);

  late final SyncService _effectiveSync;
  late final OcrService _ocrService;
  DateTime? _lastResumeSyncAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effectiveSync =
        widget.syncService ?? SyncService(controller: widget.controller);
    _ocrService = OcrService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (widget.controller.signedInEmail == null) return;
    if (widget.controller.syncStatus == SyncStatus.syncing) return;

    final now = DateTime.now().toUtc();
    if (_lastResumeSyncAt != null &&
        now.difference(_lastResumeSyncAt!) < _resumeSyncCooldown) {
      return;
    }
    _lastResumeSyncAt = now;
    widget.controller.triggerSync();
  }

  @override
  Widget build(BuildContext context) {
    final scanHandler =
        widget.onOpenScanOcr ?? (ctx) => _ocrService.openScanSheet(ctx);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return MamStringsScope(
          strings: widget.controller.strings,
          child: MaterialApp(
            title: 'Mâm',
            debugShowCheckedModeBanner: false,
            theme: buildMamTheme(),
            builder: (context, child) => MamResponsiveShell(
              child: child ?? const SizedBox.shrink(),
            ),
            home: HomeScreen(
              controller: widget.controller,
              onOpenScanOcr: scanHandler,
              syncAuthSectionBuilder: (_) => SyncAuthCard(
                controller: widget.controller,
                syncService: _effectiveSync,
              ),
            ),
          ),
        );
      },
    );
  }
}

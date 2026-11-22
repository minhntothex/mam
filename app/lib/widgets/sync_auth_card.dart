import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../services/sync_service.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';

class SyncAuthCard extends StatefulWidget {
  const SyncAuthCard({
    super.key,
    required this.controller,
    required this.syncService,
  });

  final MamController controller;
  final SyncService syncService;

  @override
  State<SyncAuthCard> createState() => _SyncAuthCardState();
}

class _SyncAuthCardState extends State<SyncAuthCard> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool isSignUp}) async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.length < 6) {
      setState(() => _error = 'Nhập email hợp lệ và mật khẩu ≥ 6 ký tự');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (isSignUp) {
        await widget.syncService.signUpWithEmail(email: email, password: pass);
      } else {
        await widget.syncService.signInWithEmail(email: email, password: pass);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final sync = widget.syncService;

    if (!sync.isConfigured) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, size: 18, color: MamColors.muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đồng bộ iOS ↔ Android (Supabase)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Đang chạy chế độ Local-first (offline 100%). Để bật đồng bộ cloud giữa iOS & Android, build app kèm --dart-define=SUPABASE_URL=... và SUPABASE_ANON_KEY=...',
                style: TextStyle(fontSize: 12.5, color: MamColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    final email = ctrl.signedInEmail;
    if (email != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_done_rounded, size: 18, color: MamColors.sage),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ctrl.lastSyncedAt == null
                    ? 'Chưa đồng bộ lần nào'
                    : 'Đồng bộ gần nhất: ${formatDateVn(ctrl.lastSyncedAt!, includeYear: true)}',
                style: const TextStyle(fontSize: 12.5, color: MamColors.muted),
              ),
              if (ctrl.lastSyncError != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Lỗi: ${ctrl.lastSyncError}',
                  style: const TextStyle(fontSize: 12, color: MamColors.danger),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: ctrl.syncStatus == SyncStatus.syncing
                          ? null
                          : () => sync.syncAll(),
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Đồng bộ ngay'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => sync.signOut(),
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đăng nhập đồng bộ iOS ↔ Android',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: MamColors.danger),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _submit(isSignUp: false),
                    child: Text(_busy ? 'Đang xử lý...' : 'Đăng nhập'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _submit(isSignUp: true),
                  child: const Text('Tạo TK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

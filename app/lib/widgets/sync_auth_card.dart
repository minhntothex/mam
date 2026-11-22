import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../l10n/mam_strings.dart';
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
    final s = context.s;
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.length < 6) {
      setState(() => _error = s.invalidAuthInput);
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
    final p = context.mam;
    final s = context.s;
    final ctrl = widget.controller;
    final sync = widget.syncService;

    if (!sync.isConfigured) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off_rounded, size: 18, color: p.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.syncSectionTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.syncUnconfiguredBody,
                style: TextStyle(fontSize: 12.5, color: p.muted),
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
                  Icon(Icons.cloud_done_rounded, size: 18, color: p.success),
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
                    ? s.neverSynced
                    : s.lastSyncedOn(
                        formatDateVn(ctrl.lastSyncedAt!, includeYear: true),
                      ),
                style: TextStyle(fontSize: 12.5, color: p.muted),
              ),
              if (ctrl.lastSyncError != null) ...[
                const SizedBox(height: 6),
                Text(
                  ctrl.lastSyncError!,
                  style: TextStyle(fontSize: 12, color: p.danger),
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
                      label: Text(s.syncNowBtn),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => sync.signOut(),
                    child: Text(s.signOutBtn),
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
            Text(
              s.signInTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: s.emailLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: s.passwordLabel),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 12, color: p.danger),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _submit(isSignUp: false),
                    child: Text(_busy ? s.working : s.signInBtn),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _submit(isSignUp: true),
                  child: Text(s.signUpBtn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

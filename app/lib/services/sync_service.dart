import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import 'supabase_config.dart';
import 'sync_merger.dart';

class SyncService {
  SyncService({required this.controller});

  final MamController controller;

  bool get isConfigured => SupabaseConfig.isConfigured;

  SupabaseClient? get _client =>
      isConfigured ? Supabase.instance.client : null;

  User? get currentUser => _client?.auth.currentUser;

  String? get accessToken => _client?.auth.currentSession?.accessToken;

  void attachToController() {
    final user = currentUser;
    controller.attachSyncHandler(
      onSyncRequested: syncAll,
      signedInUserId: user?.id,
      email: user?.email,
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase chưa được cấu hình');
    }
    await client.auth.signInWithPassword(email: email, password: password);
    attachToController();
    await syncAll();
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase chưa được cấu hình');
    }
    final redirectTo = kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : null;
    await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: redirectTo,
    );
    attachToController();
    if (currentUser != null) {
      await syncAll();
    }
  }

  Future<void> signOut() async {
    final client = _client;
    if (client != null) {
      await client.auth.signOut();
    }
    attachToController();
  }

  Future<void> syncAll() async {
    final client = _client;
    final user = currentUser;
    if (client == null || user == null) return;

    controller.setSyncState(SyncStatus.syncing);
    final uid = user.id;
    final remainingPending = Set<String>.from(controller.pendingSyncKeys);
    final lastSyncedAt = controller.lastSyncedAt;

    try {
      // 1. Push dirty records (or all local records on first-ever sync)
      final isFirstSync = lastSyncedAt == null;

      final billsToPush = controller.allBills
          .where((b) => isFirstSync || remainingPending.contains('bill:${b.id}'))
          .map((b) => b.copyWith(userId: uid))
          .toList(growable: false);
      if (billsToPush.isNotEmpty) {
        await client
            .from('bills')
            .upsert(billsToPush.map((b) => b.toJson()).toList(growable: false));
        for (final b in billsToPush) {
          remainingPending.remove('bill:${b.id}');
        }
      }

      final banksToPush = controller.allBankAccounts
          .where((a) => isFirstSync || remainingPending.contains('bank:${a.id}'))
          .map((a) => a.copyWith(userId: uid))
          .toList(growable: false);
      if (banksToPush.isNotEmpty) {
        await client.from('bank_accounts').upsert(
              banksToPush.map((a) => a.toJson()).toList(growable: false),
            );
        for (final a in banksToPush) {
          remainingPending.remove('bank:${a.id}');
        }
      }

      final groupsToPush = controller.allFriendGroups
          .where((g) => isFirstSync || remainingPending.contains('group:${g.id}'))
          .map((g) => g.copyWith(userId: uid))
          .toList(growable: false);
      if (groupsToPush.isNotEmpty) {
        await client.from('friend_groups').upsert(
              groupsToPush.map((g) => g.toJson()).toList(growable: false),
            );
        for (final g in groupsToPush) {
          remainingPending.remove('group:${g.id}');
        }
      }

      final membersToPush = controller.allMembers
          .where(
            (m) => isFirstSync || remainingPending.contains('member:${m.id}'),
          )
          .map((m) => m.copyWith(userId: uid))
          .toList(growable: false);
      if (membersToPush.isNotEmpty) {
        await client.from('members').upsert(
              membersToPush.map((m) => m.toJson()).toList(growable: false),
            );
        for (final m in membersToPush) {
          remainingPending.remove('member:${m.id}');
        }
      }

      if (isFirstSync || remainingPending.contains('settings')) {
        await client
            .from('user_settings')
            .upsert(controller.settings.copyWith(userId: uid).toJson());
        remainingPending.remove('settings');
      }

      // 2. Pull delta from Supabase (all rows on first sync)
      final sinceIso = lastSyncedAt?.toUtc().toIso8601String();

      final remoteBillsRaw = sinceIso == null
          ? await client.from('bills').select()
          : await client.from('bills').select().gt('updated_at', sinceIso);
      final remoteBanksRaw = sinceIso == null
          ? await client.from('bank_accounts').select()
          : await client
              .from('bank_accounts')
              .select()
              .gt('updated_at', sinceIso);
      final remoteGroupsRaw = sinceIso == null
          ? await client.from('friend_groups').select()
          : await client
              .from('friend_groups')
              .select()
              .gt('updated_at', sinceIso);
      final remoteMembersRaw = sinceIso == null
          ? await client.from('members').select()
          : await client.from('members').select().gt('updated_at', sinceIso);
      final remoteSettingsRaw =
          await client.from('user_settings').select().eq('user_id', uid).maybeSingle();

      final remoteBills = (remoteBillsRaw as List<dynamic>)
          .map((e) => BillRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
      final remoteBanks = (remoteBanksRaw as List<dynamic>)
          .map((e) => BankAccount.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
      final remoteGroups = (remoteGroupsRaw as List<dynamic>)
          .map((e) => FriendGroup.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false);
      final remoteMembers = (remoteMembersRaw as List<dynamic>)
          .map(
            (e) => MemberContact.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(growable: false);

      // 3. Merge via Last-Write-Wins
      final mergedBills = SyncMerger.mergeByUpdatedAt<BillRecord>(
        local: controller.allBills.map((b) => b.copyWith(userId: uid)).toList(),
        remote: remoteBills,
        idOf: (b) => b.id,
        updatedAtOf: (b) => b.updatedAt,
      );
      final mergedBanks = SyncMerger.mergeByUpdatedAt<BankAccount>(
        local: controller.allBankAccounts
            .map((a) => a.copyWith(userId: uid))
            .toList(),
        remote: remoteBanks,
        idOf: (a) => a.id,
        updatedAtOf: (a) => a.updatedAt,
      );
      final mergedGroups = SyncMerger.mergeByUpdatedAt<FriendGroup>(
        local: controller.allFriendGroups
            .map((g) => g.copyWith(userId: uid))
            .toList(),
        remote: remoteGroups,
        idOf: (g) => g.id,
        updatedAtOf: (g) => g.updatedAt,
      );
      final mergedMembers = SyncMerger.mergeByUpdatedAt<MemberContact>(
        local: controller.allMembers
            .map((m) => m.copyWith(userId: uid))
            .toList(),
        remote: remoteMembers,
        idOf: (m) => m.id,
        updatedAtOf: (m) => m.updatedAt,
      );

      var mergedSettings = controller.settings.copyWith(userId: uid);
      if (remoteSettingsRaw != null) {
        final remoteSettings = UserSettings.fromJson(
          Map<String, dynamic>.from(remoteSettingsRaw),
        );
        if (remoteSettings.updatedAt.isAfter(mergedSettings.updatedAt)) {
          mergedSettings = remoteSettings;
        }
      }

      await controller.applySyncedSnapshot(
        bills: mergedBills,
        bankAccounts: mergedBanks,
        friendGroups: mergedGroups,
        members: mergedMembers,
        settings: mergedSettings,
        remainingPendingKeys: remainingPending,
        syncedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      controller.setSyncState(SyncStatus.error, error: e.toString());
    }
  }
}

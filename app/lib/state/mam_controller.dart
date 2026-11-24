import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../core/bill_query.dart';
import '../core/calculator.dart';
import '../core/currency.dart';
import '../core/vietqr.dart';
import '../data/local_store.dart';
import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';

enum SyncStatus {
  localOnly,
  synced,
  pendingPush,
  syncing,
  error,
}

typedef SyncCallback = Future<void> Function();

class MamController extends ChangeNotifier {
  MamController({
    required this.store,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final LocalStore store;
  final Uuid _uuid;

  bool _initialized = false;
  List<BillRecord> _bills = const [];
  List<BankAccount> _bankAccounts = const [];
  List<FriendGroup> _friendGroups = const [];
  List<MemberContact> _members = const [];
  UserSettings _settings = UserSettings(
    userId: LocalStore.localDemoUserId,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
  Set<String> _pendingSyncKeys = <String>{};
  DateTime? _lastSyncedAt;
  SyncStatus _syncStatus = SyncStatus.localOnly;
  String? _lastSyncError;
  String _currentUserId = LocalStore.localDemoUserId;
  String? _signedInEmail;
  AppLanguage _language = AppLanguage.en;

  Future<void> Function()? _onSyncRequested;

  bool get initialized => _initialized;
  AppLanguage get language => _language;
  MamStrings get strings => MamStrings(_language);
  String get currentUserId => _currentUserId;
  String? get signedInEmail => _signedInEmail;
  SyncStatus get syncStatus => _syncStatus;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  Set<String> get pendingSyncKeys => Set.unmodifiable(_pendingSyncKeys);
  UserSettings get settings => _settings;
  CurrencySpec get currentCurrency =>
      CurrencyRegistry.byCode(_settings.defaultCurrency);
  AmountInputFormat get amountInputFormat => _settings.amountInputFormat;

  List<BillRecord> get allBills => List.unmodifiable(_bills);
  List<BankAccount> get allBankAccounts => List.unmodifiable(_bankAccounts);
  List<FriendGroup> get allFriendGroups => List.unmodifiable(_friendGroups);
  List<MemberContact> get allMembers => List.unmodifiable(_members);

  List<BillRecord> get activeBills {
    final list = _bills.where((b) => !b.isDeleted).toList()
      ..sort(compareBillsByPriority);
    return List.unmodifiable(list);
  }

  List<BillRecord> get pendingBills => activeBills
      .where((b) => !b.isArchived && b.paymentStatus == PaymentStatus.pending)
      .toList(growable: false);

  List<BillRecord> get settledBills => activeBills
      .where((b) => !b.isArchived && b.paymentStatus == PaymentStatus.settled)
      .toList(growable: false);

  List<BillRecord> get archivedBills =>
      activeBills.where((b) => b.isArchived).toList(growable: false);

  List<BankAccount> get activeBankAccounts =>
      _bankAccounts.where((a) => !a.isDeleted).toList(growable: false);

  BankAccount? get defaultBankAccount {
    final active = activeBankAccounts;
    if (active.isEmpty) return null;
    for (final a in active) {
      if (a.isDefault) return a;
    }
    return active.first;
  }

  List<FriendGroup> get activeFriendGroups =>
      _friendGroups.where((g) => !g.isDeleted).toList(growable: false);

  List<MemberContact> get activeMembers {
    final list = _members.where((m) => !m.isDeleted).toList()
      ..sort(
        (a, b) => normalizePersonKey(a.name).compareTo(normalizePersonKey(b.name)),
      );
    return List.unmodifiable(list);
  }

  MemberContact? findMemberById(String id) {
    for (final m in _members) {
      if (m.id == id && !m.isDeleted) return m;
    }
    return null;
  }

  MemberContact? findMemberByName(String rawName) {
    final key = normalizePersonKey(rawName);
    if (key.isEmpty) return null;
    for (final m in _members) {
      if (!m.isDeleted && normalizePersonKey(m.name) == key) return m;
    }
    return null;
  }

  /// Distinct non-empty trip names across non-archived active bills, ordered by
  /// the most recently updated bill in each trip.
  List<String> get activeTripNames {
    final seen = <String, String>{};
    final sortedBills = activeBills.where((b) => !b.isArchived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    for (final bill in sortedBills) {
      final raw = bill.payload.tripName?.trim();
      if (raw == null || raw.isEmpty) continue;
      final key = normalizePersonKey(raw);
      if (key.isEmpty) continue;
      seen.putIfAbsent(key, () => raw);
    }
    return List.unmodifiable(seen.values);
  }

  List<BillRecord> billsForTrip(String tripName) {
    final key = normalizePersonKey(tripName);
    if (key.isEmpty) return const [];
    return activeBills
        .where(
          (b) =>
              b.payload.tripName != null &&
              normalizePersonKey(b.payload.tripName!) == key,
        )
        .toList(growable: false);
  }

  static String normalizePersonKey(String raw) =>
      VietQrGenerator.removeVietnameseDiacritics(raw).toLowerCase().trim();

  /// Sum of unpaid positive net amounts owed by non-host participants across
  /// pending bills, grouped by currency code so multi-currency bills never mix.
  Map<String, int> get uncollectedByCurrency {
    final totals = <String, int>{};
    for (final bill in pendingBills) {
      final code = CurrencyRegistry.byCode(bill.payload.currencyCode).code;
      final calc = BillCalculator.calculate(bill.payload);
      for (final b in calc.breakdowns) {
        if (!b.participant.isHost && !b.participant.paid && b.collectAmount > 0) {
          totals[code] = (totals[code] ?? 0) + b.collectAmount;
        }
      }
    }
    return totals;
  }

  /// Sum of unpaid refunds the Host still owes to overpaid non-host members
  /// across pending multi-payer bills, grouped by currency code.
  Map<String, int> get toRefundByCurrency {
    final totals = <String, int>{};
    for (final bill in pendingBills) {
      final code = CurrencyRegistry.byCode(bill.payload.currencyCode).code;
      final calc = BillCalculator.calculate(bill.payload);
      for (final b in calc.breakdowns) {
        if (!b.participant.isHost && !b.participant.paid && b.refundAmount > 0) {
          totals[code] = (totals[code] ?? 0) + b.refundAmount;
        }
      }
    }
    return totals;
  }

  /// Primary uncollected total in the user's current default currency (or the
  /// first currency with a pending balance).
  int get totalUncollectedAmount {
    final map = uncollectedByCurrency;
    if (map.isEmpty) return 0;
    return map[currentCurrency.code] ?? map.values.first;
  }

  BillRecord? findBillById(String id) {
    for (final b in _bills) {
      if (b.id == id) return b;
    }
    return null;
  }

  String newId() => _uuid.v4();

  Future<void> init({bool seedDemo = false}) async {
    final snapshot = await store.loadOrSeed(seedDemo: seedDemo);
    _bills = List<BillRecord>.from(snapshot.bills);
    _bankAccounts = List<BankAccount>.from(snapshot.bankAccounts);
    _friendGroups = List<FriendGroup>.from(snapshot.friendGroups);
    _members = List<MemberContact>.from(snapshot.members);
    _settings = snapshot.settings;
    _pendingSyncKeys = Set<String>.from(snapshot.pendingSyncKeys);
    _lastSyncedAt = snapshot.lastSyncedAt;
    _language = snapshot.language;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    await store.saveLanguage(language);
    notifyListeners();
  }

  void attachSyncHandler({
    required Future<void> Function() onSyncRequested,
    String? signedInUserId,
    String? email,
  }) {
    _onSyncRequested = onSyncRequested;
    if (signedInUserId != null) {
      _currentUserId = signedInUserId;
      _signedInEmail = email;
      _syncStatus = _pendingSyncKeys.isEmpty
          ? SyncStatus.synced
          : SyncStatus.pendingPush;
    } else {
      _currentUserId = LocalStore.localDemoUserId;
      _signedInEmail = null;
      _syncStatus = SyncStatus.localOnly;
    }
    notifyListeners();
  }

  void setSyncState(SyncStatus status, {String? error, DateTime? syncedAt}) {
    _syncStatus = status;
    _lastSyncError = error;
    if (syncedAt != null) {
      _lastSyncedAt = syncedAt;
      store.saveLastSyncedAt(syncedAt);
    }
    notifyListeners();
  }

  Future<void> triggerSync() async {
    if (_onSyncRequested == null) return;
    await _onSyncRequested!();
  }

  Future<void> applySyncedSnapshot({
    required List<BillRecord> bills,
    required List<BankAccount> bankAccounts,
    required List<FriendGroup> friendGroups,
    List<MemberContact>? members,
    required UserSettings settings,
    required Set<String> remainingPendingKeys,
    required DateTime syncedAt,
  }) async {
    _bills = List<BillRecord>.from(bills);
    _bankAccounts = List<BankAccount>.from(bankAccounts);
    _friendGroups = List<FriendGroup>.from(friendGroups);
    if (members != null) {
      _members = List<MemberContact>.from(members);
    }
    _settings = settings;
    _pendingSyncKeys = Set<String>.from(remainingPendingKeys);
    _lastSyncedAt = syncedAt;
    _syncStatus = remainingPendingKeys.isEmpty
        ? SyncStatus.synced
        : SyncStatus.pendingPush;
    _lastSyncError = null;
    await store.saveAll(
      LocalDataSnapshot(
        bills: _bills,
        bankAccounts: _bankAccounts,
        friendGroups: _friendGroups,
        members: _members,
        settings: _settings,
        pendingSyncKeys: _pendingSyncKeys,
        lastSyncedAt: _lastSyncedAt,
      ),
    );
    notifyListeners();
  }

  Future<BillRecord> saveBill(BillRecord bill) async {
    final now = DateTime.now().toUtc();
    final calc = BillCalculator.calculate(bill.payload);
    final normalizedPayload = BillCalculator.normalizeParticipantPaidStates(
      bill.payload,
      calc: calc,
    );
    final normalized = bill.copyWith(
      userId: _currentUserId,
      totalAmount: calc.computedGrandTotal,
      paymentStatus: BillCalculator.computePaymentStatus(
        normalizedPayload,
        calc: calc,
      ),
      payload: normalizedPayload,
      updatedAt: now,
    );

    final idx = _bills.indexWhere((b) => b.id == normalized.id);
    if (idx >= 0) {
      _bills[idx] = normalized;
    } else {
      _bills.insert(0, normalized);
    }

    _markPending('bill:${normalized.id}');
    await _persistBills();
    notifyListeners();
    _triggerSyncBestEffort();
    return normalized;
  }

  Future<void> deleteBill(String billId) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx < 0) return;
    final now = DateTime.now().toUtc();
    _bills[idx] = _bills[idx].copyWith(deletedAt: now, updatedAt: now);
    _markPending('bill:$billId');
    await _persistBills();
    notifyListeners();
    _triggerSyncBestEffort();
  }

  Future<void> archiveBill(String billId) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx < 0 || _bills[idx].isArchived) return;
    final now = DateTime.now().toUtc();
    _bills[idx] = _bills[idx].copyWith(archivedAt: now, updatedAt: now);
    _markPending('bill:$billId');
    await _persistBills();
    notifyListeners();
    _triggerSyncBestEffort();
  }

  Future<void> unarchiveBill(String billId) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx < 0 || !_bills[idx].isArchived) return;
    final now = DateTime.now().toUtc();
    _bills[idx] = _bills[idx].copyWith(archivedAt: null, updatedAt: now);
    _markPending('bill:$billId');
    await _persistBills();
    notifyListeners();
    _triggerSyncBestEffort();
  }

  Future<void> toggleParticipantPaid(String billId, String participantId) async {
    final bill = findBillById(billId);
    if (bill == null) return;
    final now = DateTime.now().toUtc();
    final updatedParticipants = bill.payload.participants.map((p) {
      if (p.id != participantId) return p;
      final nextPaid = !p.paid;
      return p.copyWith(
        paid: nextPaid,
        paidAt: nextPaid ? now : null,
      );
    }).toList(growable: false);

    final updatedPayload = bill.payload.copyWith(participants: updatedParticipants);
    await saveBill(bill.copyWith(payload: updatedPayload));
  }

  /// Marks multiple `(billId, participantId)` targets as paid/unpaid in a
  /// single local persist + single sync trigger.
  Future<int> markPersonPaidAcrossBills(
    List<({String billId, String participantId})> targets, {
    bool paid = true,
  }) async {
    if (targets.isEmpty) return 0;
    final byBill = <String, Set<String>>{};
    for (final t in targets) {
      byBill.putIfAbsent(t.billId, () => <String>{}).add(t.participantId);
    }

    final now = DateTime.now().toUtc();
    var updatedBillCount = 0;

    for (final entry in byBill.entries) {
      final idx = _bills.indexWhere((b) => b.id == entry.key);
      if (idx < 0) continue;
      final bill = _bills[idx];
      var changed = false;
      final updatedParticipants = bill.payload.participants.map((p) {
        if (!entry.value.contains(p.id) || p.isHost || p.paid == paid) {
          return p;
        }
        changed = true;
        return p.copyWith(
          paid: paid,
          paidAt: paid ? now : null,
        );
      }).toList(growable: false);
      if (!changed) continue;

      final updatedPayload =
          bill.payload.copyWith(participants: updatedParticipants);
      final calc = BillCalculator.calculate(updatedPayload);
      final normalizedPayload = BillCalculator.normalizeParticipantPaidStates(
        updatedPayload,
        calc: calc,
      );
      _bills[idx] = bill.copyWith(
        userId: _currentUserId,
        totalAmount: calc.computedGrandTotal,
        paymentStatus: BillCalculator.computePaymentStatus(
          normalizedPayload,
          calc: calc,
        ),
        payload: normalizedPayload,
        updatedAt: now,
      );
      _markPending('bill:${bill.id}');
      updatedBillCount++;
    }

    if (updatedBillCount > 0) {
      await _persistBills();
      notifyListeners();
      _triggerSyncBestEffort();
    }
    return updatedBillCount;
  }

  Future<void> updateBillRounding(String billId, RoundingMode mode) async {
    final bill = findBillById(billId);
    if (bill == null) return;
    await saveBill(
      bill.copyWith(payload: bill.payload.copyWith(roundingMode: mode)),
    );
  }

  Future<void> updateBillBankAccount(String billId, BankAccount account) async {
    final bill = findBillById(billId);
    if (bill == null) return;
    await saveBill(
      bill.copyWith(
        payload: bill.payload.copyWith(
          bankAccountSnapshot: account.toSnapshot(),
        ),
      ),
    );
  }

  Future<void> saveBankAccount(BankAccount account) async {
    final now = DateTime.now().toUtc();
    final normalized = account.copyWith(
      userId: _currentUserId,
      updatedAt: now,
    );

    // Enforce single active default bank account.
    if (normalized.isDefault) {
      for (var i = 0; i < _bankAccounts.length; i++) {
        final other = _bankAccounts[i];
        if (other.id != normalized.id && other.isDefault && !other.isDeleted) {
          _bankAccounts[i] = other.copyWith(isDefault: false, updatedAt: now);
          _markPending('bank:${other.id}');
        }
      }
    }

    final idx = _bankAccounts.indexWhere((a) => a.id == normalized.id);
    if (idx >= 0) {
      _bankAccounts[idx] = normalized;
    } else {
      _bankAccounts.add(normalized);
    }

    _markPending('bank:${normalized.id}');
    await Future.wait([
      store.saveBankAccounts(_bankAccounts),
      store.savePendingSyncKeys(_pendingSyncKeys),
    ]);
    notifyListeners();
    _triggerSyncBestEffort();
  }

  Future<void> deleteBankAccount(String id) async {
    final idx = _bankAccounts.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final now = DateTime.now().toUtc();
    _bankAccounts[idx] = _bankAccounts[idx].copyWith(
      isDefault: false,
      deletedAt: now,
      updatedAt: now,
    );
    _markPending('bank:$id');
    await Future.wait([
      store.saveBankAccounts(_bankAccounts),
      store.savePendingSyncKeys(_pendingSyncKeys),
    ]);
    notifyListeners();
    _triggerSyncBestEffort();
  }

  Future<void> saveFriendGroup(FriendGroup group) async {
    final now = DateTime.now().toUtc();
    final normalized = group.copyWith(
      userId: _currentUserId,
      updatedAt: now,
    );
    final idx = _friendGroups.indexWhere((g) => g.id == normalized.id);
    if (idx >= 0) {
      _friendGroups[idx] = normalized;
    } else {
      _friendGroups.add(normalized);
    }
    _markPending('group:${normalized.id}');
    await Future.wait([
      store.saveFriendGroups(_friendGroups),
      store.savePendingSyncKeys(_pendingSyncKeys),
    ]);
    notifyListeners();
    _triggerSyncBestEffort();
  }

  Future<void> deleteFriendGroup(String id) async {
    final idx = _friendGroups.indexWhere((g) => g.id == id);
    if (idx < 0) return;
    final now = DateTime.now().toUtc();
    _friendGroups[idx] = _friendGroups[idx].copyWith(
      deletedAt: now,
      updatedAt: now,
    );
    _markPending('group:$id');
    await Future.wait([
      store.saveFriendGroups(_friendGroups),
      store.savePendingSyncKeys(_pendingSyncKeys),
    ]);
    notifyListeners();
    _triggerSyncBestEffort();
  }

  /// Returns an existing active contact matching [rawName] (case & diacritic
  /// insensitive), or creates and persists a new [MemberContact].
  Future<MemberContact> ensureMemberContact(String rawName) async {
    final trimmed = rawName.trim();
    final existing = findMemberByName(trimmed);
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    final contact = MemberContact(
      id: newId(),
      userId: _currentUserId,
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );
    await saveMemberContact(contact);
    return contact;
  }

  Future<void> saveMemberContact(MemberContact contact) async {
    final trimmed = contact.name.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now().toUtc();
    final normalized = contact.copyWith(
      userId: _currentUserId,
      name: trimmed,
      updatedAt: now,
    );
    final idx = _members.indexWhere((m) => m.id == normalized.id);
    if (idx >= 0) {
      _members[idx] = normalized;
    } else {
      _members.add(normalized);
    }
    _markPending('member:${normalized.id}');
    await Future.wait([
      store.saveMembers(_members),
      store.savePendingSyncKeys(_pendingSyncKeys),
    ]);
    notifyListeners();
    _triggerSyncBestEffort();
  }

  Future<void> deleteMemberContact(String id) async {
    final idx = _members.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final now = DateTime.now().toUtc();
    _members[idx] = _members[idx].copyWith(
      deletedAt: now,
      updatedAt: now,
    );
    _markPending('member:$id');
    await Future.wait([
      store.saveMembers(_members),
      store.savePendingSyncKeys(_pendingSyncKeys),
    ]);
    notifyListeners();
    _triggerSyncBestEffort();
  }

  Future<void> updateSettings(UserSettings next) async {
    _settings = next.copyWith(
      userId: _currentUserId,
      updatedAt: DateTime.now().toUtc(),
    );
    _markPending('settings');
    await Future.wait([
      store.saveSettings(_settings),
      store.savePendingSyncKeys(_pendingSyncKeys),
    ]);
    notifyListeners();
    _triggerSyncBestEffort();
  }

  void _markPending(String key) {
    if (_signedInEmail == null) return;
    _pendingSyncKeys.add(key);
    _syncStatus = SyncStatus.pendingPush;
  }

  Future<void> _persistBills() async {
    await Future.wait([
      store.saveBills(_bills),
      store.savePendingSyncKeys(_pendingSyncKeys),
    ]);
  }

  void _triggerSyncBestEffort() {
    if (_onSyncRequested != null && _signedInEmail != null) {
      _onSyncRequested!();
    }
  }
}

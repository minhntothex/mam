import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bill_models.dart';

// Local-first JSON store backed by SharedPreferences (works on iOS, Android, and Web).

final class LocalDataSnapshot {
  const LocalDataSnapshot({
    required this.bills,
    required this.bankAccounts,
    required this.friendGroups,
    required this.settings,
    required this.pendingSyncKeys,
    required this.lastSyncedAt,
  });

  final List<BillRecord> bills;
  final List<BankAccount> bankAccounts;
  final List<FriendGroup> friendGroups;
  final UserSettings settings;
  final Set<String> pendingSyncKeys;
  final DateTime? lastSyncedAt;
}

class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _kSeeded = 'mam_seeded_v1';
  static const String _kBills = 'mam_bills_v1';
  static const String _kBankAccounts = 'mam_bank_accounts_v1';
  static const String _kFriendGroups = 'mam_friend_groups_v1';
  static const String _kSettings = 'mam_settings_v1';
  static const String _kPendingSync = 'mam_pending_sync_v1';
  static const String _kLastSyncedAt = 'mam_last_synced_at_v1';
  static const String localDemoUserId = '00000000-0000-0000-0000-000000000001';

  static Future<LocalStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore(prefs);
  }

  Future<LocalDataSnapshot> loadOrSeed() async {
    final seeded = _prefs.getBool(_kSeeded) ?? false;
    if (!seeded) {
      final initial = _buildDemoSeed();
      await saveAll(initial);
      await _prefs.setBool(_kSeeded, true);
      return initial;
    }

    final bills = _decodeList(_prefs.getString(_kBills), BillRecord.fromJson);
    final banks =
        _decodeList(_prefs.getString(_kBankAccounts), BankAccount.fromJson);
    final groups =
        _decodeList(_prefs.getString(_kFriendGroups), FriendGroup.fromJson);

    final rawSettings = _prefs.getString(_kSettings);
    final settings = rawSettings != null
        ? UserSettings.fromJson(
            Map<String, dynamic>.from(jsonDecode(rawSettings) as Map),
          )
        : UserSettings(userId: localDemoUserId, updatedAt: DateTime.now().toUtc());

    final pending = (_prefs.getStringList(_kPendingSync) ?? const []).toSet();
    final rawSync = _prefs.getString(_kLastSyncedAt);
    final lastSync = rawSync == null ? null : DateTime.tryParse(rawSync);

    return LocalDataSnapshot(
      bills: bills,
      bankAccounts: banks,
      friendGroups: groups,
      settings: settings,
      pendingSyncKeys: pending,
      lastSyncedAt: lastSync,
    );
  }

  Future<LocalDataSnapshot> resetToDemoSeed() async {
    final initial = _buildDemoSeed();
    await saveAll(initial);
    await _prefs.setBool(_kSeeded, true);
    return initial;
  }

  Future<void> saveAll(LocalDataSnapshot snapshot) async {
    await Future.wait([
      saveBills(snapshot.bills),
      saveBankAccounts(snapshot.bankAccounts),
      saveFriendGroups(snapshot.friendGroups),
      saveSettings(snapshot.settings),
      savePendingSyncKeys(snapshot.pendingSyncKeys),
      saveLastSyncedAt(snapshot.lastSyncedAt),
    ]);
  }

  Future<void> saveBills(List<BillRecord> bills) async {
    await _prefs.setString(
      _kBills,
      jsonEncode(bills.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  Future<void> saveBankAccounts(List<BankAccount> accounts) async {
    await _prefs.setString(
      _kBankAccounts,
      jsonEncode(accounts.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  Future<void> saveFriendGroups(List<FriendGroup> groups) async {
    await _prefs.setString(
      _kFriendGroups,
      jsonEncode(groups.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  Future<void> saveSettings(UserSettings settings) async {
    await _prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }

  Future<void> savePendingSyncKeys(Set<String> keys) async {
    await _prefs.setStringList(_kPendingSync, keys.toList(growable: false));
  }

  Future<void> saveLastSyncedAt(DateTime? timestamp) async {
    if (timestamp == null) {
      await _prefs.remove(_kLastSyncedAt);
    } else {
      await _prefs.setString(_kLastSyncedAt, timestamp.toUtc().toIso8601String());
    }
  }

  List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) return <T>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  LocalDataSnapshot _buildDemoSeed() {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final defaultBank = BankAccount(
      id: '11111111-1111-4111-8111-111111111101',
      userId: localDemoUserId,
      bankBin: '970436',
      bankShortName: 'Vietcombank',
      accountNo: '0123456789',
      accountName: 'NGUYEN VAN MINH',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    );

    final secondBank = BankAccount(
      id: '11111111-1111-4111-8111-111111111102',
      userId: localDemoUserId,
      bankBin: '970407',
      bankShortName: 'Techcombank',
      accountNo: '19036888999001',
      accountName: 'NGUYEN VAN MINH',
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    );

    final teamGroup = FriendGroup(
      id: '22222222-2222-4222-8222-222222222201',
      userId: localDemoUserId,
      name: 'Team Công ty',
      members: const [
        GroupMember(id: 'm_me', name: 'Tôi', isHost: true),
        GroupMember(id: 'm_minh', name: 'Minh'),
        GroupMember(id: 'm_lan', name: 'Lan'),
        GroupMember(id: 'm_hung', name: 'Hùng'),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final friendsGroup = FriendGroup(
      id: '22222222-2222-4222-8222-222222222202',
      userId: localDemoUserId,
      name: 'Hội bạn thân',
      members: const [
        GroupMember(id: 'f_me', name: 'Tôi', isHost: true),
        GroupMember(id: 'f_duc', name: 'Đức'),
        GroupMember(id: 'f_vy', name: 'Vy'),
        GroupMember(id: 'f_khoi', name: 'Khôi'),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final haidilaoBill = BillRecord(
      id: '33333333-3333-4333-8333-333333333301',
      userId: localDemoUserId,
      title: 'Lẩu Haidilao Bitexco',
      billDate: today,
      mode: BillMode.itemized,
      totalAmount: 966400,
      paymentStatus: PaymentStatus.pending,
      payload: BillPayload(
        participants: [
          const Participant(id: 'p_me', name: 'Tôi', isHost: true, paid: true),
          Participant(id: 'p_minh', name: 'Minh', paid: true, paidAt: now),
          const Participant(id: 'p_lan', name: 'Lan', paid: false),
          const Participant(id: 'p_hung', name: 'Hùng', paid: false),
        ],
        items: const [
          BillItem(
            id: 'i1',
            name: 'Nước lẩu cà chua & thái',
            quantity: 1,
            lineTotal: 260000,
            shares: {'p_me': 1, 'p_minh': 1, 'p_lan': 1, 'p_hung': 1},
          ),
          BillItem(
            id: 'i2',
            name: 'Thịt bò Mỹ cuộn',
            quantity: 2,
            lineTotal: 340000,
            shares: {'p_me': 1, 'p_minh': 1, 'p_lan': 1, 'p_hung': 1},
          ),
          BillItem(
            id: 'i3',
            name: 'Tôm phỉ thúy & đậu hũ phô mai',
            quantity: 1,
            lineTotal: 190000,
            shares: {'p_me': 1, 'p_minh': 1, 'p_lan': 1, 'p_hung': 1},
          ),
          BillItem(
            id: 'i4',
            name: 'Bia Tiger lon',
            quantity: 4,
            lineTotal: 120000,
            shares: {'p_me': 2, 'p_hung': 2},
          ),
          BillItem(
            id: 'i5',
            name: 'Trà sữa trân châu',
            quantity: 2,
            lineTotal: 80000,
            shares: {'p_minh': 1, 'p_lan': 1},
          ),
        ],
        adjustments: const BillAdjustments(
          taxAmount: 76400,
          serviceChargeAmount: 0,
          shippingAmount: 0,
          shippingMode: ShippingSplitMode.flat,
          billDiscountAmount: 100000,
          ocrGrandTotal: 966400,
        ),
        roundingMode: RoundingMode.nearest1000,
        bankAccountSnapshot: defaultBank.toSnapshot(),
      ),
      createdAt: now,
      updatedAt: now,
    );

    final milkTeaBill = BillRecord(
      id: '33333333-3333-4333-8333-333333333302',
      userId: localDemoUserId,
      title: 'Phê La chiều (GrabFood)',
      billDate: yesterday,
      mode: BillMode.itemized,
      totalAmount: 187000,
      paymentStatus: PaymentStatus.settled,
      payload: BillPayload(
        participants: [
          const Participant(id: 'p_me', name: 'Tôi', isHost: true, paid: true),
          Participant(id: 'p_duc', name: 'Đức', paid: true, paidAt: yesterday),
          Participant(id: 'p_vy', name: 'Vy', paid: true, paidAt: yesterday),
        ],
        items: const [
          BillItem(
            id: 'g1',
            name: 'Ô long sữa Phê La (L)',
            quantity: 1,
            lineTotal: 65000,
            shares: {'p_me': 1},
          ),
          BillItem(
            id: 'g2',
            name: 'Trà vỏ cà phê',
            quantity: 1,
            lineTotal: 60000,
            shares: {'p_duc': 1},
          ),
          BillItem(
            id: 'g3',
            name: 'Matcha Phan Xi Păng',
            quantity: 1,
            lineTotal: 70000,
            shares: {'p_vy': 1},
          ),
        ],
        adjustments: const BillAdjustments(
          shippingAmount: 22000,
          shippingMode: ShippingSplitMode.flat,
          billDiscountAmount: 30000,
          ocrGrandTotal: 187000,
        ),
        roundingMode: RoundingMode.nearest1000,
        bankAccountSnapshot: defaultBank.toSnapshot(),
      ),
      createdAt: yesterday,
      updatedAt: yesterday,
    );

    return LocalDataSnapshot(
      bills: [haidilaoBill, milkTeaBill],
      bankAccounts: [defaultBank, secondBank],
      friendGroups: [teamGroup, friendsGroup],
      settings: UserSettings(
        userId: localDemoUserId,
        defaultRounding: RoundingMode.nearest1000,
        defaultTransferTemplate: '{name} tra tien {title}',
        defaultShippingMode: ShippingSplitMode.flat,
        updatedAt: now,
      ),
      pendingSyncKeys: <String>{},
      lastSyncedAt: null,
    );
  }
}

/// Mâm (mam) — Pure Dart 3 Domain Models
///
/// Maps 1:1 with:
/// - `supabase/migrations/001_init.sql` (snake_case DB columns)
/// - `bills.payload` & `friend_groups.members` JSONB structures (camelCase)
/// - `POST /functions/v1/scan-bill` OCR response contract (camelCase)
///
/// Zero external package dependencies so this drops directly into a fresh
/// Flutter project without codegen (`build_runner`/`freezed`).

const Object _unset = Object();

// ============================================================================
// Enums
// ============================================================================

enum BillMode {
  itemized('itemized'),
  quickEqual('quick_equal');

  const BillMode(this.value);
  final String value;

  static BillMode fromValue(String? raw) {
    return BillMode.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => BillMode.itemized,
    );
  }
}

enum PaymentStatus {
  pending('pending'),
  settled('settled');

  const PaymentStatus(this.value);
  final String value;

  static PaymentStatus fromValue(String? raw) {
    return PaymentStatus.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => PaymentStatus.pending,
    );
  }
}

enum RoundingMode {
  none('none'),
  nearest1000('nearest_1000'),
  ceil1000('ceil_1000');

  const RoundingMode(this.value);
  final String value;

  static RoundingMode fromValue(String? raw) {
    return RoundingMode.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => RoundingMode.nearest1000,
    );
  }
}

enum ShippingSplitMode {
  flat('flat'),
  proRata('pro_rata');

  const ShippingSplitMode(this.value);
  final String value;

  static ShippingSplitMode fromValue(String? raw) {
    return ShippingSplitMode.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => ShippingSplitMode.flat,
    );
  }
}

enum OcrConfidence {
  high('high'),
  medium('medium'),
  low('low');

  const OcrConfidence(this.value);
  final String value;

  static OcrConfidence fromValue(String? raw) {
    return OcrConfidence.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => OcrConfidence.medium,
    );
  }
}

// ============================================================================
// Database Record Models (Supabase tables — snake_case JSON keys)
// ============================================================================

final class BankAccount {
  const BankAccount({
    required this.id,
    required this.userId,
    required this.bankBin,
    required this.bankShortName,
    required this.accountNo,
    this.accountName,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String bankBin;
  final String bankShortName;
  final String accountNo;
  final String? accountName;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  BankAccountSnapshot toSnapshot() => BankAccountSnapshot(
        bankBin: bankBin,
        bankShortName: bankShortName,
        accountNo: accountNo,
        accountName: accountName,
      );

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bankBin: json['bank_bin'] as String,
      bankShortName: json['bank_short_name'] as String,
      accountNo: json['account_no'] as String,
      accountName: json['account_name'] as String?,
      isDefault: (json['is_default'] as bool?) ?? false,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      deletedAt: _parseNullableDateTime(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'bank_bin': bankBin,
        'bank_short_name': bankShortName,
        'account_no': accountNo,
        'account_name': accountName,
        'is_default': isDefault,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };

  BankAccount copyWith({
    String? id,
    String? userId,
    String? bankBin,
    String? bankShortName,
    String? accountNo,
    Object? accountName = _unset,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) {
    return BankAccount(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bankBin: bankBin ?? this.bankBin,
      bankShortName: bankShortName ?? this.bankShortName,
      accountNo: accountNo ?? this.accountNo,
      accountName:
          identical(accountName, _unset) ? this.accountName : accountName as String?,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          identical(deletedAt, _unset) ? this.deletedAt : deletedAt as DateTime?,
    );
  }
}

final class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    this.isHost = false,
  });

  final String id;
  final String name;
  final bool isHost;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      name: json['name'] as String,
      isHost: (json['isHost'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isHost': isHost,
      };

  GroupMember copyWith({
    String? id,
    String? name,
    bool? isHost,
  }) {
    return GroupMember(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
    );
  }
}

final class FriendGroup {
  const FriendGroup({
    required this.id,
    required this.userId,
    required this.name,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final List<GroupMember> members;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory FriendGroup.fromJson(Map<String, dynamic> json) {
    final rawMembers = (json['members'] as List<dynamic>?) ?? const [];
    return FriendGroup(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      members: rawMembers
          .map((e) => GroupMember.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      deletedAt: _parseNullableDateTime(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'members': members.map((m) => m.toJson()).toList(growable: false),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };

  FriendGroup copyWith({
    String? id,
    String? userId,
    String? name,
    List<GroupMember>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) {
    return FriendGroup(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          identical(deletedAt, _unset) ? this.deletedAt : deletedAt as DateTime?,
    );
  }
}

final class UserSettings {
  const UserSettings({
    required this.userId,
    this.defaultRounding = RoundingMode.nearest1000,
    this.defaultTransferTemplate = '{name} tra tien {title}',
    this.defaultShippingMode = ShippingSplitMode.flat,
    required this.updatedAt,
  });

  final String userId;
  final RoundingMode defaultRounding;
  final String defaultTransferTemplate;
  final ShippingSplitMode defaultShippingMode;
  final DateTime updatedAt;

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      userId: json['user_id'] as String,
      defaultRounding: RoundingMode.fromValue(json['default_rounding'] as String?),
      defaultTransferTemplate:
          (json['default_transfer_template'] as String?) ??
              '{name} tra tien {title}',
      defaultShippingMode:
          ShippingSplitMode.fromValue(json['default_shipping_mode'] as String?),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'default_rounding': defaultRounding.value,
        'default_transfer_template': defaultTransferTemplate,
        'default_shipping_mode': defaultShippingMode.value,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  UserSettings copyWith({
    String? userId,
    RoundingMode? defaultRounding,
    String? defaultTransferTemplate,
    ShippingSplitMode? defaultShippingMode,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      defaultRounding: defaultRounding ?? this.defaultRounding,
      defaultTransferTemplate:
          defaultTransferTemplate ?? this.defaultTransferTemplate,
      defaultShippingMode: defaultShippingMode ?? this.defaultShippingMode,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

final class BillRecord {
  const BillRecord({
    required this.id,
    required this.userId,
    required this.title,
    required this.billDate,
    this.mode = BillMode.itemized,
    required this.totalAmount,
    this.paymentStatus = PaymentStatus.pending,
    this.schemaVersion = 1,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String title;
  final DateTime billDate;
  final BillMode mode;
  final int totalAmount;
  final PaymentStatus paymentStatus;
  final int schemaVersion;
  final BillPayload payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  factory BillRecord.fromJson(Map<String, dynamic> json) {
    return BillRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      billDate: _parseDateOnly(json['bill_date']),
      mode: BillMode.fromValue(json['mode'] as String?),
      totalAmount: _parseInt(json['total_amount']),
      paymentStatus: PaymentStatus.fromValue(json['payment_status'] as String?),
      schemaVersion: _parseInt(json['schema_version'], fallback: 1),
      payload: BillPayload.fromJson(
        Map<String, dynamic>.from(json['payload'] as Map),
      ),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      deletedAt: _parseNullableDateTime(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'bill_date': _formatDateOnly(billDate),
        'mode': mode.value,
        'total_amount': totalAmount,
        'payment_status': paymentStatus.value,
        'schema_version': schemaVersion,
        'payload': payload.toJson(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };

  BillRecord copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? billDate,
    BillMode? mode,
    int? totalAmount,
    PaymentStatus? paymentStatus,
    int? schemaVersion,
    BillPayload? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) {
    return BillRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      billDate: billDate ?? this.billDate,
      mode: mode ?? this.mode,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          identical(deletedAt, _unset) ? this.deletedAt : deletedAt as DateTime?,
    );
  }
}

// ============================================================================
// Bill Payload Models (`bills.payload` JSONB — camelCase JSON keys)
// ============================================================================

final class Participant {
  const Participant({
    required this.id,
    required this.name,
    this.isHost = false,
    this.paid = false,
    this.paidAt,
  });

  final String id;
  final String name;
  final bool isHost;
  final bool paid;
  final DateTime? paidAt;

  factory Participant.fromJson(Map<String, dynamic> json) {
    final isHost = (json['isHost'] as bool?) ?? false;
    return Participant(
      id: json['id'] as String,
      name: json['name'] as String,
      isHost: isHost,
      paid: (json['paid'] as bool?) ?? isHost,
      paidAt: _parseNullableDateTime(json['paidAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isHost': isHost,
        'paid': paid,
        if (paidAt != null) 'paidAt': paidAt!.toUtc().toIso8601String(),
      };

  Participant copyWith({
    String? id,
    String? name,
    bool? isHost,
    bool? paid,
    Object? paidAt = _unset,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      paid: paid ?? this.paid,
      paidAt: identical(paidAt, _unset) ? this.paidAt : paidAt as DateTime?,
    );
  }
}

final class BillItem {
  const BillItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    required this.lineTotal,
    this.itemDiscount = 0,
    this.shares = const {},
  });

  final String id;
  final String name;
  final double quantity;
  final int lineTotal;
  final int itemDiscount;

  /// Map of `{ participantId: shareWeight }`.
  /// Empty map or sum of weights <= 0 means the item is unassigned.
  final Map<String, double> shares;

  int get netTotal => lineTotal > itemDiscount ? lineTotal - itemDiscount : 0;

  double get totalShareWeight =>
      shares.values.fold<double>(0, (sum, weight) => sum + (weight > 0 ? weight : 0));

  bool get isAssigned => totalShareWeight > 0;

  factory BillItem.fromJson(Map<String, dynamic> json) {
    final rawShares = json['shares'];
    final parsedShares = <String, double>{};
    if (rawShares is Map) {
      for (final entry in rawShares.entries) {
        final weight = _parseDouble(entry.value);
        if (weight > 0) {
          parsedShares[entry.key.toString()] = weight;
        }
      }
    }
    return BillItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: _parseDouble(json['quantity'], fallback: 1),
      lineTotal: _parseInt(json['lineTotal']),
      itemDiscount: _parseInt(json['itemDiscount']),
      shares: Map<String, double>.unmodifiable(parsedShares),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'lineTotal': lineTotal,
        'itemDiscount': itemDiscount,
        'shares': shares,
      };

  BillItem copyWith({
    String? id,
    String? name,
    double? quantity,
    int? lineTotal,
    int? itemDiscount,
    Map<String, double>? shares,
  }) {
    return BillItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      lineTotal: lineTotal ?? this.lineTotal,
      itemDiscount: itemDiscount ?? this.itemDiscount,
      shares: shares ?? this.shares,
    );
  }
}

final class BillAdjustments {
  const BillAdjustments({
    this.taxAmount = 0,
    this.serviceChargeAmount = 0,
    this.shippingAmount = 0,
    this.shippingMode = ShippingSplitMode.flat,
    this.billDiscountAmount = 0,
    this.ocrGrandTotal,
  });

  final int taxAmount;
  final int serviceChargeAmount;
  final int shippingAmount;
  final ShippingSplitMode shippingMode;
  final int billDiscountAmount;
  final int? ocrGrandTotal;

  factory BillAdjustments.fromJson(Map<String, dynamic> json) {
    return BillAdjustments(
      taxAmount: _parseInt(json['taxAmount']),
      serviceChargeAmount: _parseInt(json['serviceChargeAmount']),
      shippingAmount: _parseInt(json['shippingAmount']),
      shippingMode: ShippingSplitMode.fromValue(json['shippingMode'] as String?),
      billDiscountAmount: _parseInt(json['billDiscountAmount']),
      ocrGrandTotal: json['ocrGrandTotal'] == null
          ? null
          : _parseInt(json['ocrGrandTotal']),
    );
  }

  Map<String, dynamic> toJson() => {
        'taxAmount': taxAmount,
        'serviceChargeAmount': serviceChargeAmount,
        'shippingAmount': shippingAmount,
        'shippingMode': shippingMode.value,
        'billDiscountAmount': billDiscountAmount,
        if (ocrGrandTotal != null) 'ocrGrandTotal': ocrGrandTotal,
      };

  BillAdjustments copyWith({
    int? taxAmount,
    int? serviceChargeAmount,
    int? shippingAmount,
    ShippingSplitMode? shippingMode,
    int? billDiscountAmount,
    Object? ocrGrandTotal = _unset,
  }) {
    return BillAdjustments(
      taxAmount: taxAmount ?? this.taxAmount,
      serviceChargeAmount: serviceChargeAmount ?? this.serviceChargeAmount,
      shippingAmount: shippingAmount ?? this.shippingAmount,
      shippingMode: shippingMode ?? this.shippingMode,
      billDiscountAmount: billDiscountAmount ?? this.billDiscountAmount,
      ocrGrandTotal: identical(ocrGrandTotal, _unset)
          ? this.ocrGrandTotal
          : ocrGrandTotal as int?,
    );
  }
}

final class BankAccountSnapshot {
  const BankAccountSnapshot({
    required this.bankBin,
    required this.bankShortName,
    required this.accountNo,
    this.accountName,
  });

  final String bankBin;
  final String bankShortName;
  final String accountNo;
  final String? accountName;

  factory BankAccountSnapshot.fromJson(Map<String, dynamic> json) {
    return BankAccountSnapshot(
      bankBin: json['bankBin'] as String,
      bankShortName: json['bankShortName'] as String,
      accountNo: json['accountNo'] as String,
      accountName: json['accountName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'bankBin': bankBin,
        'bankShortName': bankShortName,
        'accountNo': accountNo,
        if (accountName != null) 'accountName': accountName,
      };
}

final class BillPayload {
  const BillPayload({
    required this.participants,
    required this.items,
    this.adjustments = const BillAdjustments(),
    this.roundingMode = RoundingMode.nearest1000,
    this.bankAccountSnapshot,
    this.transferNoteTemplate = '{name} tra tien {title}',
    this.note,
  });

  final List<Participant> participants;
  final List<BillItem> items;
  final BillAdjustments adjustments;
  final RoundingMode roundingMode;
  final BankAccountSnapshot? bankAccountSnapshot;
  final String transferNoteTemplate;
  final String? note;

  factory BillPayload.fromJson(Map<String, dynamic> json) {
    final rawParticipants = (json['participants'] as List<dynamic>?) ?? const [];
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    final rawAdjustments = json['adjustments'];
    final rawBank = json['bankAccountSnapshot'];

    return BillPayload(
      participants: rawParticipants
          .map((e) => Participant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      items: rawItems
          .map((e) => BillItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      adjustments: rawAdjustments is Map
          ? BillAdjustments.fromJson(Map<String, dynamic>.from(rawAdjustments))
          : const BillAdjustments(),
      roundingMode: RoundingMode.fromValue(json['roundingMode'] as String?),
      bankAccountSnapshot: rawBank is Map
          ? BankAccountSnapshot.fromJson(Map<String, dynamic>.from(rawBank))
          : null,
      transferNoteTemplate: (json['transferNoteTemplate'] as String?) ??
          '{name} tra tien {title}',
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'participants':
            participants.map((p) => p.toJson()).toList(growable: false),
        'items': items.map((i) => i.toJson()).toList(growable: false),
        'adjustments': adjustments.toJson(),
        'roundingMode': roundingMode.value,
        if (bankAccountSnapshot != null)
          'bankAccountSnapshot': bankAccountSnapshot!.toJson(),
        'transferNoteTemplate': transferNoteTemplate,
        if (note != null) 'note': note,
      };

  BillPayload copyWith({
    List<Participant>? participants,
    List<BillItem>? items,
    BillAdjustments? adjustments,
    RoundingMode? roundingMode,
    Object? bankAccountSnapshot = _unset,
    String? transferNoteTemplate,
    Object? note = _unset,
  }) {
    return BillPayload(
      participants: participants ?? this.participants,
      items: items ?? this.items,
      adjustments: adjustments ?? this.adjustments,
      roundingMode: roundingMode ?? this.roundingMode,
      bankAccountSnapshot: identical(bankAccountSnapshot, _unset)
          ? this.bankAccountSnapshot
          : bankAccountSnapshot as BankAccountSnapshot?,
      transferNoteTemplate: transferNoteTemplate ?? this.transferNoteTemplate,
      note: identical(note, _unset) ? this.note : note as String?,
    );
  }
}

// ============================================================================
// OCR Edge Function Contract (`POST /functions/v1/scan-bill`)
// ============================================================================

final class OcrScanItem {
  const OcrScanItem({
    required this.name,
    this.quantity = 1,
    required this.lineTotal,
    this.itemDiscount = 0,
  });

  final String name;
  final double quantity;
  final int lineTotal;
  final int itemDiscount;

  factory OcrScanItem.fromJson(Map<String, dynamic> json) {
    return OcrScanItem(
      name: (json['name'] as String?)?.trim() ?? '',
      quantity: _parseDouble(json['quantity'], fallback: 1),
      lineTotal: _parseInt(json['lineTotal']),
      itemDiscount: _parseInt(json['itemDiscount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'lineTotal': lineTotal,
        'itemDiscount': itemDiscount,
      };
}

final class OcrScanResult {
  const OcrScanResult({
    this.title,
    this.billDate,
    required this.items,
    this.taxAmount = 0,
    this.serviceChargeAmount = 0,
    this.shippingAmount = 0,
    this.billDiscountAmount = 0,
    this.ocrGrandTotal,
    this.confidence = OcrConfidence.medium,
  });

  final String? title;
  final DateTime? billDate;
  final List<OcrScanItem> items;
  final int taxAmount;
  final int serviceChargeAmount;
  final int shippingAmount;
  final int billDiscountAmount;
  final int? ocrGrandTotal;
  final OcrConfidence confidence;

  factory OcrScanResult.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return OcrScanResult(
      title: json['title'] as String?,
      billDate:
          json['billDate'] == null ? null : _parseDateOnly(json['billDate']),
      items: rawItems
          .map((e) => OcrScanItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      taxAmount: _parseInt(json['taxAmount']),
      serviceChargeAmount: _parseInt(json['serviceChargeAmount']),
      shippingAmount: _parseInt(json['shippingAmount']),
      billDiscountAmount: _parseInt(json['billDiscountAmount']),
      ocrGrandTotal: json['ocrGrandTotal'] == null
          ? null
          : _parseInt(json['ocrGrandTotal']),
      confidence: OcrConfidence.fromValue(json['confidence'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (billDate != null) 'billDate': _formatDateOnly(billDate!),
        'items': items.map((i) => i.toJson()).toList(growable: false),
        'taxAmount': taxAmount,
        'serviceChargeAmount': serviceChargeAmount,
        'shippingAmount': shippingAmount,
        'billDiscountAmount': billDiscountAmount,
        if (ocrGrandTotal != null) 'ocrGrandTotal': ocrGrandTotal,
        'confidence': confidence.value,
      };
}

// ============================================================================
// Parsing & Formatting Helpers
// ============================================================================

int _parseInt(Object? raw, {int fallback = 0}) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

double _parseDouble(Object? raw, {double fallback = 0}) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

DateTime _parseDateTime(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.parse(raw);
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _parseNullableDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
  return null;
}

DateTime _parseDateOnly(Object? raw) {
  if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);
  if (raw is String && raw.isNotEmpty) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
  }
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _formatDateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../data/bank_bins.dart';
import '../models/bill_models.dart';
import '../state/mam_controller.dart';
import '../theme/mam_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.syncAuthSectionBuilder,
  });

  final MamController controller;
  final Widget Function(BuildContext context)? syncAuthSectionBuilder;

  @override
  Widget build(BuildContext context) {
    final p = context.mam;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final banks = controller.activeBankAccounts;
        final groups = controller.activeFriendGroups;
        final settings = controller.settings;

        return Scaffold(
          appBar: AppBar(title: const Text('Cài đặt')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // 0. Appearance (Light / Dark / System)
              const Text(
                'Giao diện',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chế độ hiển thị (Sáng / Tối)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('Hệ thống'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Sáng'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Tối'),
                            ),
                          ],
                          selected: {controller.themeMode},
                          onSelectionChanged: (s) =>
                              controller.setThemeMode(s.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 1. Bank Accounts
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tài khoản ngân hàng (VietQR)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openBankEditor(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Thêm STK'),
                  ),
                ],
              ),
              if (banks.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Chưa có tài khoản nhận tiền. Thêm 1 STK để tạo mã VietQR tự động.',
                      style: TextStyle(color: p.muted),
                    ),
                  ),
                )
              else
                ...banks.map(
                  (bank) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: bank.isDefault
                              ? p.primarySoft
                              : p.surfaceSubtle,
                          child: Icon(
                            Icons.account_balance_rounded,
                            size: 18,
                            color: bank.isDefault ? p.primary : p.muted,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                bank.bankShortName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (bank.isDefault) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: p.primarySoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Mặc định',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: p.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${bank.accountNo}${bank.accountName != null && bank.accountName!.isNotEmpty ? ' · ${bank.accountName}' : ''}',
                          style: kTabularStyle.copyWith(fontSize: 12.5),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'default') {
                              await controller.saveBankAccount(
                                bank.copyWith(isDefault: true),
                              );
                            } else if (value == 'edit') {
                              if (context.mounted) {
                                await _openBankEditor(context, existing: bank);
                              }
                            } else if (value == 'delete') {
                              await controller.deleteBankAccount(bank.id);
                            }
                          },
                          itemBuilder: (_) => [
                            if (!bank.isDefault)
                              const PopupMenuItem(
                                value: 'default',
                                child: Text('Đặt làm mặc định'),
                              ),
                            const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Xóa', style: TextStyle(color: p.danger)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // 2. Friend Groups
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nhóm hay đi ăn cùng',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openGroupEditor(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Thêm nhóm'),
                  ),
                ],
              ),
              if (groups.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Chưa có nhóm nào.',
                      style: TextStyle(color: p.muted),
                    ),
                  ),
                )
              else
                ...groups.map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.surfaceSubtle,
                          child: Icon(Icons.groups_2_rounded, size: 18, color: p.ink),
                        ),
                        title: Text(
                          g.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          g.members.map((m) => m.name).join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          onPressed: () => controller.deleteFriendGroup(g.id),
                        ),
                        onTap: () => _openGroupEditor(context, existing: g),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // 3. Defaults
              const Text(
                'Mặc định chia tiền',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Làm tròn mặc định',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<RoundingMode>(
                          segments: const [
                            ButtonSegment(value: RoundingMode.none, label: Text('Không')),
                            ButtonSegment(value: RoundingMode.nearest1000, label: Text('Gần 1k')),
                            ButtonSegment(value: RoundingMode.ceil1000, label: Text('Lên 1k')),
                          ],
                          selected: {settings.defaultRounding},
                          onSelectionChanged: (s) => controller.updateSettings(
                            settings.copyWith(defaultRounding: s.first),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Chia tiền ship mặc định',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ShippingSplitMode>(
                          segments: const [
                            ButtonSegment(value: ShippingSplitMode.flat, label: Text('Chia đều')),
                            ButtonSegment(value: ShippingSplitMode.proRata, label: Text('Theo tỷ lệ')),
                          ],
                          selected: {settings.defaultShippingMode},
                          onSelectionChanged: (s) => controller.updateSettings(
                            settings.copyWith(defaultShippingMode: s.first),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Mẫu nội dung chuyển khoản',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(settings.defaultTransferTemplate),
                        trailing: const Icon(Icons.edit_outlined, size: 18),
                        onTap: () => _editTemplateDialog(context, settings),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 4. Sync / Account Section
              if (syncAuthSectionBuilder != null)
                syncAuthSectionBuilder!(context)
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đồng bộ iOS ↔ Android (Supabase)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.lastSyncedAt == null
                              ? 'Đang chạy chế độ Local-first (offline 100%).'
                              : 'Đồng bộ gần nhất: ${formatDateVn(controller.lastSyncedAt!, includeYear: true)}',
                          style: TextStyle(fontSize: 12.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await controller.resetDemoData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã khôi phục dữ liệu mẫu Demo')),
                    );
                  }
                },
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Khôi phục dữ liệu mẫu Demo'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openBankEditor(
    BuildContext context, {
    BankAccount? existing,
  }) async {
    var selectedBank =
        findBankByBin(existing?.bankBin ?? '970436') ?? kVietnamBanks.first;
    final accNoCtrl = TextEditingController(text: existing?.accountNo ?? '');
    final accNameCtrl = TextEditingController(text: existing?.accountName ?? '');
    var isDefault = existing?.isDefault ?? controller.activeBankAccounts.isEmpty;
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final p = ctx.mam;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = kVietnamBanks.where((b) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return b.shortName.toLowerCase().contains(q) ||
                  b.code.toLowerCase().contains(q) ||
                  b.bin.contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null ? 'Thêm tài khoản ngân hàng' : 'Sửa tài khoản',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        hintText: 'Tìm ngân hàng (VCB, TCB, MB, Timo...)',
                      ),
                      onChanged: (v) => setModalState(() => query = v),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, idx) {
                          final bank = filtered[idx];
                          final active = bank.bin == selectedBank.bin;
                          return ListTile(
                            dense: true,
                            selected: active,
                            selectedTileColor: p.primarySoft,
                            title: Text('${bank.shortName} (${bank.code})'),
                            trailing: Text(bank.bin, style: kTabularStyle),
                            onTap: () => setModalState(() => selectedBank = bank),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: accNoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Số tài khoản'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: accNameCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Tên chủ tài khoản (tùy chọn)',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isDefault,
                      onChanged: (v) => setModalState(() => isDefault = v ?? false),
                      title: const Text('Đặt làm tài khoản mặc định'),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (accNoCtrl.text.trim().isEmpty) return;
                          final now = DateTime.now().toUtc();
                          final account = BankAccount(
                            id: existing?.id ?? controller.newId(),
                            userId: controller.currentUserId,
                            bankBin: selectedBank.bin,
                            bankShortName: selectedBank.shortName,
                            accountNo: accNoCtrl.text.trim(),
                            accountName: accNameCtrl.text.trim().isEmpty
                                ? null
                                : accNameCtrl.text.trim().toUpperCase(),
                            isDefault: isDefault,
                            createdAt: existing?.createdAt ?? now,
                            updatedAt: now,
                          );
                          await controller.saveBankAccount(account);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Lưu tài khoản'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    accNoCtrl.dispose();
    accNameCtrl.dispose();
  }

  Future<void> _openGroupEditor(
    BuildContext context, {
    FriendGroup? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final membersCtrl = TextEditingController(
      text: existing?.members.map((m) => m.name).join(', ') ?? 'Tôi, Minh, Lan',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Thêm nhóm bạn' : 'Sửa nhóm bạn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên nhóm'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: membersCtrl,
              decoration: const InputDecoration(
                labelText: 'Thành viên (cách nhau bởi dấu phẩy)',
                helperText: 'Người đầu tiên mặc định là Chủ xị',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final title = nameCtrl.text.trim();
              final names = membersCtrl.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (title.isEmpty || names.isEmpty) return;
              final now = DateTime.now().toUtc();
              final group = FriendGroup(
                id: existing?.id ?? controller.newId(),
                userId: controller.currentUserId,
                name: title,
                members: [
                  for (var i = 0; i < names.length; i++)
                    GroupMember(
                      id: 'gm_$i',
                      name: names[i],
                      isHost: i == 0,
                    ),
                ],
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
              );
              await controller.saveFriendGroup(group);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    membersCtrl.dispose();
  }

  Future<void> _editTemplateDialog(
    BuildContext context,
    UserSettings settings,
  ) async {
    final ctrl = TextEditingController(text: settings.defaultTransferTemplate);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mẫu nội dung CK'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            helperText: 'Dùng {name} (tên người) và {title} (tên bill)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved != null && saved.isNotEmpty) {
      await controller.updateSettings(
        settings.copyWith(defaultTransferTemplate: saved),
      );
    }
  }
}

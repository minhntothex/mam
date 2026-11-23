import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/amount_input_formatter.dart';
import '../core/currency.dart';
import '../core/formatters.dart';
import '../data/bank_bins.dart';
import '../l10n/mam_strings.dart';
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
    final s = context.s;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final banks = controller.activeBankAccounts;
        final groups = controller.activeFriendGroups;
        final settings = controller.settings;
        final currency = controller.currentCurrency;
        final inputFormat = controller.amountInputFormat;
        final resolvedFormat = currency.resolveInputFormat(inputFormat);
        final stepLabel = s.isVi
            ? currency.roundingStepLabelVi
            : currency.roundingStepLabelEn;
        final previewSamples = [1000, 312592, 5923892]
            .map(
              (n) => formatAmountForInput(
                n,
                currency: currency,
                format: inputFormat,
              ),
            )
            .join(' · ');
        final formatHint = switch (resolvedFormat) {
          AmountInputFormat.usdDecimal => s.formatAtmHint,
          AmountInputFormat.plain => s.formatPlainHint,
          _ => s.formatDotHint,
        };

        return Scaffold(
          appBar: AppBar(title: Text(s.settings)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // 0. Language
              Text(
                s.languageLabel,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AppLanguage>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: AppLanguage.en,
                          label: Text(AppLanguage.en.label),
                        ),
                        ButtonSegment(
                          value: AppLanguage.vi,
                          label: Text(AppLanguage.vi.label),
                        ),
                      ],
                      selected: {controller.language},
                      onSelectionChanged: (sel) =>
                          controller.setLanguage(sel.first),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 0b. Currency & Amount Input Format (scalable)
              Text(
                s.currencyAndFormatSection,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.currencyLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final spec in CurrencyRegistry.all)
                            ChoiceChip(
                              showCheckmark: false,
                              label: Text(spec.label),
                              selected: spec.code == currency.code,
                              selectedColor: p.primaryFill,
                              side: BorderSide(
                                color: spec.code == currency.code
                                    ? p.primaryFill
                                    : p.border,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: spec.code == currency.code
                                    ? p.onPrimary
                                    : p.ink,
                              ),
                              onSelected: (_) => controller.updateSettings(
                                settings.copyWith(defaultCurrency: spec.code),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        s.amountFormatLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<AmountInputFormat>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: AmountInputFormat.auto,
                              label: Text(s.formatAuto),
                            ),
                            ButtonSegment(
                              value: AmountInputFormat.dotThousands,
                              label: Text(s.formatDotThousands),
                            ),
                            ButtonSegment(
                              value: AmountInputFormat.usdDecimal,
                              label: Text(s.formatUsdDecimal),
                            ),
                            ButtonSegment(
                              value: AmountInputFormat.plain,
                              label: Text(s.formatPlain),
                            ),
                          ],
                          selected: {inputFormat},
                          onSelectionChanged: (sel) => controller.updateSettings(
                            settings.copyWith(amountInputFormat: sel.first),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: p.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.formatPreviewLabel}: $previewSamples',
                              style: kTabularStyle.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatHint,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: p.muted,
                              ),
                            ),
                          ],
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
                  Expanded(
                    child: Text(
                      s.bankSection,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openBankEditor(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(s.addBankBtn),
                  ),
                ],
              ),
              if (banks.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      s.noBankEmpty,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
                                  s.defaultBadge,
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
                              PopupMenuItem(
                                value: 'default',
                                child: Text(s.setDefault),
                              ),
                            PopupMenuItem(value: 'edit', child: Text(s.edit)),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(s.delete, style: TextStyle(color: p.danger)),
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
                  Expanded(
                    child: Text(
                      s.groupsSection,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openGroupEditor(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(s.addGroupBtn),
                  ),
                ],
              ),
              if (groups.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      s.noGroupsEmpty,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
              Text(
                s.defaultsSection,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.defaultRoundingLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<RoundingMode>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: RoundingMode.none,
                              label: Text(s.roundNone),
                            ),
                            ButtonSegment(
                              value: RoundingMode.ceil1000,
                              label: Text(s.roundCeilStep(stepLabel)),
                            ),
                          ],
                          selected: {settings.defaultRounding},
                          onSelectionChanged: (sel) => controller.updateSettings(
                            settings.copyWith(defaultRounding: sel.first),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        s.defaultShipLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ShippingSplitMode>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: ShippingSplitMode.flat,
                              label: Text(s.shipFlatFull),
                            ),
                            ButtonSegment(
                              value: ShippingSplitMode.proRata,
                              label: Text(s.shipProRataFull),
                            ),
                          ],
                          selected: {settings.defaultShippingMode},
                          onSelectionChanged: (sel) => controller.updateSettings(
                            settings.copyWith(defaultShippingMode: sel.first),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Material(
                        color: p.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          title: Text(
                            s.transferTemplateLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            settings.defaultTransferTemplate,
                            style: TextStyle(fontSize: 12.5, color: p.muted),
                          ),
                          trailing: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: p.muted,
                          ),
                          onTap: () => _editTemplateDialog(context, settings),
                        ),
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
                        Text(
                          s.syncSectionTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.lastSyncedAt == null
                              ? s.syncUnconfiguredBody
                              : s.lastSyncedOn(
                                  formatDateVn(
                                    controller.lastSyncedAt!,
                                    includeYear: true,
                                  ),
                                ),
                          style: TextStyle(fontSize: 12.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
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
    final s = context.s;
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
                      existing == null ? s.addBankTitle : s.editBankTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        hintText: s.searchBankHint,
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: s.accountNoLabel),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: accNameCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: s.accountHolderLabel,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: p.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        value: isDefault,
                        onChanged: (v) =>
                            setModalState(() => isDefault = v ?? false),
                        title: Text(
                          s.setAsDefaultAccount,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        child: Text(s.saveAccountBtn),
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
    final s = context.s;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final membersCtrl = TextEditingController(
      text: existing?.members.map((m) => m.name).join(', ') ??
          '${s.me}, Minh, Lan',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? s.addGroupTitle : s.editGroupTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: s.groupNameLabel),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: membersCtrl,
              decoration: InputDecoration(
                labelText: s.membersLabel,
                helperText: s.firstMemberIsHost,
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final title = nameCtrl.text.trim();
              final names = membersCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
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
            child: Text(s.save),
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
    final s = context.s;
    final ctrl = TextEditingController(text: settings.defaultTransferTemplate);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.transferTemplateLabel),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            helperText: s.transferTemplateHelp,
            helperMaxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(s.save),
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

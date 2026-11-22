import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';
import '../theme/mam_theme.dart';
import 'supabase_config.dart';

class OcrService {
  OcrService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<OcrScanResult?> openScanSheet(BuildContext context) async {
    final p = context.mam;
    final s = context.s;
    return showModalBottomSheet<OcrScanResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.ocrSheetTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!kIsWeb)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: p.primarySoft,
                    child: Icon(Icons.camera_alt_rounded, color: p.primary),
                  ),
                  title: Text(
                    s.takePhotoTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(s.takePhotoSub),
                  onTap: () => _pickAndRun(ctx, ImageSource.camera, s),
                ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: CircleAvatar(
                  backgroundColor: p.primarySoft,
                  child: Icon(Icons.photo_library_rounded, color: p.primary),
                ),
                title: Text(
                  s.pickPhotoTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  SupabaseConfig.isConfigured
                      ? s.pickPhotoSubConfigured
                      : s.pickPhotoSubUnconfigured,
                ),
                onTap: () => _pickAndRun(ctx, ImageSource.gallery, s),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              Text(
                s.demoPresetsHeading,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 6),
              ...demoPresets(isVi: s.isVi).map(
                (preset) => ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(
                    Icons.receipt_long_rounded,
                    color: p.ink,
                    size: 20,
                  ),
                  title: Text(
                    preset.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    preset.subtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => Navigator.pop(ctx, preset.result),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndRun(
    BuildContext ctx,
    ImageSource source,
    MamStrings s,
  ) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 75,
    );
    if (file == null) return;

    if (!SupabaseConfig.isConfigured) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(s.ocrNeedsSupabase)),
        );
      }
      return;
    }

    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(s.ocrNeedsLogin)),
        );
      }
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final response = await client.functions.invoke(
        'scan-bill',
        body: {
          'imageBase64': base64Image,
          'mimeType': 'image/jpeg',
        },
      );

      final data = response.data;
      if (data is Map) {
        final parsed = OcrScanResult.fromJson(Map<String, dynamic>.from(data));
        if (ctx.mounted) Navigator.pop(ctx, parsed);
        return;
      }
      throw StateError('Invalid OCR response');
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('OCR error: $e')),
        );
      }
    }
  }

  static List<DemoOcrPreset> demoPresets({bool isVi = false}) {
    final today = DateTime.now();
    return [
      DemoOcrPreset(
        label: isVi
            ? 'Quán Nhậu Bờ Kè (có VAT 8% & lệch 10k OCR)'
            : 'Bo Ke Street Grill (8% VAT & 10k OCR diff)',
        subtitle: isVi
            ? 'Test đối chiếu tổng tự động + chia bia theo lon'
            : 'Tests reconciliation bar + per-can beer stepper',
        result: OcrScanResult(
          title: 'Quán Nhậu Bờ Kè',
          billDate: today,
          items: const [
            OcrScanItem(name: 'Lẩu cá kèo lá giang', quantity: 1, lineTotal: 250000),
            OcrScanItem(name: 'Mực nướng muối ớt', quantity: 1, lineTotal: 185000),
            OcrScanItem(name: 'Bia Sài Gòn Special', quantity: 6, lineTotal: 132000),
            OcrScanItem(name: 'Khăn lạnh & đậu phộng', quantity: 4, lineTotal: 20000),
          ],
          taxAmount: 46960,
          serviceChargeAmount: 0,
          shippingAmount: 0,
          billDiscountAmount: 0,
          ocrGrandTotal: 643960,
          confidence: OcrConfidence.medium,
        ),
      ),
      DemoOcrPreset(
        label: isVi
            ? 'GrabFood Bún Đậu Mắm Tôm (Ship 18k + Voucher 25k)'
            : 'GrabFood Bun Dau (18k Ship + 25k Voucher)',
        subtitle: isVi
            ? 'Test chia ship đều vs tỷ lệ + giảm giá toàn bill'
            : 'Tests equal vs pro-rata shipping + bill voucher',
        result: OcrScanResult(
          title: 'Bún Đậu Cô Khàn (GrabFood)',
          billDate: today,
          items: const [
            OcrScanItem(name: 'Mẹt bún đậu đầy đủ', quantity: 2, lineTotal: 130000),
            OcrScanItem(name: 'Mẹt bún đậu chả cốm', quantity: 1, lineTotal: 55000),
            OcrScanItem(name: 'Trà tắc khổng lồ', quantity: 3, lineTotal: 45000),
          ],
          taxAmount: 0,
          serviceChargeAmount: 0,
          shippingAmount: 18000,
          billDiscountAmount: 25000,
          ocrGrandTotal: 223000,
          confidence: OcrConfidence.high,
        ),
      ),
      DemoOcrPreset(
        label: isVi
            ? 'Highlands Coffee (5 ly trà & cà phê)'
            : 'Highlands Coffee (5 drinks & snacks)',
        subtitle: isVi
            ? 'Test stepper +/- gán nhanh món số lượng > 1'
            : 'Tests +/- stepper for multi-quantity items',
        result: OcrScanResult(
          title: 'Highlands Coffee',
          billDate: today,
          items: const [
            OcrScanItem(name: 'Trà Sen Vàng (M)', quantity: 3, lineTotal: 165000),
            OcrScanItem(name: 'Phin Sữa Đá (M)', quantity: 2, lineTotal: 78000),
            OcrScanItem(name: 'Bánh Mì Que', quantity: 2, lineTotal: 38000),
          ],
          taxAmount: 0,
          serviceChargeAmount: 0,
          shippingAmount: 0,
          billDiscountAmount: 30000,
          ocrGrandTotal: 251000,
          confidence: OcrConfidence.high,
        ),
      ),
    ];
  }
}

final class DemoOcrPreset {
  const DemoOcrPreset({
    required this.label,
    required this.subtitle,
    required this.result,
  });

  final String label;
  final String subtitle;
  final OcrScanResult result;
}

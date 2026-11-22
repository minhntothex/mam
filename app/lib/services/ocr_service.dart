import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bill_models.dart';
import '../theme/mam_theme.dart';
import 'supabase_config.dart';

class OcrService {
  OcrService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<OcrScanResult?> openScanSheet(BuildContext context) async {
    final p = context.mam;
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
                  const Expanded(
                    child: Text(
                      'Scan hóa đơn (AI OCR)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                  leading: CircleAvatar(
                    backgroundColor: p.primarySoft,
                    child: Icon(Icons.camera_alt_rounded, color: p.primary),
                  ),
                  title: const Text(
                    'Chụp ảnh hóa đơn',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Gửi qua Edge Function /scan-bill'),
                  onTap: () => _pickAndRun(ctx, ImageSource.camera),
                ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.primarySoft,
                  child: Icon(Icons.photo_library_rounded, color: p.primary),
                ),
                title: const Text(
                  'Chọn ảnh hóa đơn từ máy',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  SupabaseConfig.isConfigured
                      ? 'Trích xuất tự động bằng Gemini 2.5 Flash'
                      : 'Cần cấu hình Supabase để gọi AI thật (dùng mẫu Demo bên dưới)',
                ),
                onTap: () => _pickAndRun(ctx, ImageSource.gallery),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              Text(
                'Thử nhanh hóa đơn mẫu VN (Demo Offline)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 6),
              ...demoPresets.map(
                (preset) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
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

  Future<void> _pickAndRun(BuildContext ctx, ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 75,
    );
    if (file == null) return;

    if (!SupabaseConfig.isConfigured) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa kết nối Supabase OCR proxy — hãy chọn 1 hóa đơn mẫu Demo để trải nghiệm luồng OCR.',
            ),
          ),
        );
      }
      return;
    }

    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập trong Cài đặt trước khi scan OCR.'),
          ),
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
      throw StateError('Phản hồi OCR không hợp lệ');
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Lỗi scan OCR: $e')),
        );
      }
    }
  }

  static List<DemoOcrPreset> get demoPresets {
    final today = DateTime.now();
    return [
      DemoOcrPreset(
        label: 'Quán Nhậu Bờ Kè (có VAT 8% & lệch 10k OCR)',
        subtitle: 'Test đối chiếu tổng tự động + chia bia theo lon',
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
          // Deliberately +10,000đ off to showcase the red OCR reconciliation warning!
          ocrGrandTotal: 643960,
          confidence: OcrConfidence.medium,
        ),
      ),
      DemoOcrPreset(
        label: 'GrabFood Bún Đậu Mắm Tôm (Ship 18k + Voucher 25k)',
        subtitle: 'Test chia ship đều vs tỷ lệ + giảm giá toàn bill',
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
        label: 'Highlands Coffee (5 ly trà & cà phê)',
        subtitle: 'Test stepper +/- gán nhanh món số lượng > 1',
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

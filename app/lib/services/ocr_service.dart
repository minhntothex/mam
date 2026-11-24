import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/mam_strings.dart';
import '../models/bill_models.dart';
import '../theme/mam_theme.dart';
import 'supabase_config.dart';

typedef OcrScanRunner = Future<OcrScanResult?> Function(
  ImageSource source,
  MamStrings strings,
);

class OcrService {
  OcrService({
    ImagePicker? picker,
    this.scanRunner,
  }) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final OcrScanRunner? scanRunner;

  Future<OcrScanResult?> openScanSheet(BuildContext context) async {
    final p = context.mam;
    return showModalBottomSheet<OcrScanResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      builder: (ctx) => _OcrScanSheet(
        runScan: scanRunner ?? _pickAndInvoke,
      ),
    );
  }

  Future<OcrScanResult?> _pickAndInvoke(
    ImageSource source,
    MamStrings s,
  ) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 75,
    );
    if (file == null) return null;

    if (!SupabaseConfig.isConfigured) {
      throw _OcrUserException(s.ocrNeedsSupabase);
    }

    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw _OcrUserException(s.ocrNeedsLogin);
    }

    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = detectImageMimeType(file);

    try {
      final response = await client.functions.invoke(
        'scan-bill',
        body: {
          'imageBase64': base64Image,
          'mimeType': mimeType,
        },
      );

      final data = response.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final errText = map['error'];
        if (errText is String && errText.trim().isNotEmpty) {
          throw _OcrUserException(errText.trim());
        }
        return OcrScanResult.fromJson(map);
      }
      throw const _OcrUserException('Invalid OCR response');
    } on _OcrUserException {
      rethrow;
    } on FunctionException catch (e) {
      throw _OcrUserException(formatOcrError(e.details ?? e.reasonPhrase ?? e));
    } catch (e) {
      throw _OcrUserException(formatOcrError(e));
    }
  }

  static String detectImageMimeType(XFile file) {
    final explicit = file.mimeType?.trim().toLowerCase();
    if (explicit != null && explicit.startsWith('image/')) {
      return explicit;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  static String formatOcrError(Object raw) {
    if (raw is _OcrUserException) return raw.message;
    if (raw is Map) {
      final err = raw['error'];
      if (err is String && err.trim().isNotEmpty) return err.trim();
      final msg = raw['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    final text = raw.toString().trim();
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          final err = decoded['error'];
          if (err is String && err.trim().isNotEmpty) return err.trim();
          if (err is Map && err['message'] is String) {
            return (err['message'] as String).trim();
          }
        }
      } catch (_) {
        // Fall back to cleaned raw string
      }
    }
    return text.replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
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
          currencyCode: 'VND',
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
          currencyCode: 'VND',
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
          currencyCode: 'VND',
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

class _OcrScanSheet extends StatefulWidget {
  const _OcrScanSheet({required this.runScan});

  final OcrScanRunner runScan;

  @override
  State<_OcrScanSheet> createState() => _OcrScanSheetState();
}

class _OcrScanSheetState extends State<_OcrScanSheet> {
  bool _isScanning = false;
  String? _errorMessage;

  Future<void> _handlePick(ImageSource source) async {
    if (_isScanning) return;
    final s = context.s;
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.runScan(source, s);
      if (!mounted) return;
      if (result != null) {
        Navigator.pop(context, result);
        return;
      }
      // User cancelled image picker
      setState(() => _isScanning = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorMessage = OcrService.formatOcrError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.mam;
    final s = context.s;

    return PopScope(
      canPop: !_isScanning,
      child: SafeArea(
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
                    onPressed: _isScanning ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (_isScanning) ...[
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('ocr_loading_panel'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: p.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: p.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: p.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.ocrScanningTitle,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              s.ocrScanningSub,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: p.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                if (_errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    key: const ValueKey('ocr_error_banner'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.dangerSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: p.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: p.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.ocrErrorTitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: p.danger,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.ocrRetryHint,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: p.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () => setState(() => _errorMessage = null),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                if (!kIsWeb)
                  ListTile(
                    key: const ValueKey('ocr_camera_tile'),
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
                    onTap: () => _handlePick(ImageSource.camera),
                  ),
                ListTile(
                  key: const ValueKey('ocr_gallery_tile'),
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
                  onTap: () => _handlePick(ImageSource.gallery),
                ),
                if (!SupabaseConfig.isConfigured) ...[
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
                  ...OcrService.demoPresets(isVi: s.isVi).map(
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
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      onTap: () => Navigator.pop(context, preset.result),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OcrUserException implements Exception {
  const _OcrUserException(this.message);

  final String message;

  @override
  String toString() => message;
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

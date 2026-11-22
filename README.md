# Mâm (`mam`)

App chia bill cá nhân (**Single-Player + VietQR Offline**), đồng bộ 2 chiều **iOS ↔ Android** bằng **Flutter + Supabase**.

## Tính năng MVP v1.0
- **Chia đều siêu tốc (< 5 giây):** Nhập tổng tiền + nhóm/số người → ra ngay kết quả & VietQR.
- **Scan hóa đơn AI OCR (Gemini 2.5 Flash) hoặc nhập tay:** Kèm thanh đối chiếu tổng tự động (`computedGrandTotal` vs `ocrGrandTotal`) và 3 hóa đơn mẫu VN để test offline.
- **Gán món siêu tốc:** Chọn người ở thanh trên → chạm liên tiếp vào món, nút `Cả bàn`, stepper `+/-` cho món số lượng > 1, giữ lâu để multi-select nhóm con, cảnh báo món chưa gán.
- **Xử lý chuẩn hóa đơn VN:** Pro-rata VAT / phí phục vụ / giảm giá toàn bill, tách giảm giá riêng từng món, tùy chọn tiền ship `Chia đều` hoặc `Theo tỷ lệ`, làm tròn `1.000đ` (`Không` / `Gần nhất` / `Lên 1k`) hiển thị rõ chênh lệch.
- **VietQR động 100% offline (EMVCo NAPAS 247):** Tự sinh chuỗi TLV + bỏ dấu tiếng Việt + `CRC16-CCITT-FALSE`, hỗ trợ 32 ngân hàng VN.
- **Xuất ảnh PNG chia sẻ Zalo/Messenger:** `SummaryReceiptCard` tổng hợp và `PersonQrCard` động từng người.
- **Local-first + Đồng bộ 2 chiều iOS ↔ Android:** Hoạt động bình thường khi offline; đồng bộ delta Last-Write-Wins + soft-delete khi cấu hình Supabase.

## Chạy bản Demo nhanh (Local / Web / Mobile)

```bash
cd app
flutter pub get
flutter test

# Chạy demo trên Chrome (không cần cấu hình Supabase)
flutter run -d chrome

# Hoặc build bản Web release tĩnh
flutter build web --release
```

## Kích hoạt Sync iOS ↔ Android & OCR thật (Supabase)

1. Tạo project tại [Supabase](https://supabase.com), chạy file SQL [supabase/migrations/001_init.sql](supabase/migrations/001_init.sql) trong **SQL Editor**.
2. Deploy Edge Function OCR và nạp `GEMINI_API_KEY` (không lưu key trong app):
   ```bash
   supabase link --project-ref <PROJECT_REF>
   supabase secrets set GEMINI_API_KEY=<YOUR_GEMINI_KEY>
   supabase functions deploy scan-bill
   ```
3. Chạy hoặc build app kèm `--dart-define`:
   ```bash
   cd app
   flutter run \
     --dart-define=SUPABASE_URL=https://<PROJECT_REF>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<YOUR_PUBLISHABLE_KEY>
   ```
4. Build cài đặt cá nhân:
   - **Android:** `flutter build apk --release --dart-define=...`
   - **iOS:** mở `app/ios/Runner.xcworkspace` trong Xcode hoặc `flutter build ipa --release --dart-define=...`

## Tài liệu
- Đặc tả MVP & Data Schema: [docs/mvp-spec.md](docs/mvp-spec.md)

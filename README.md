# Mâm (`mam`)

App chia bill cá nhân (**Single-Player + VietQR Offline**), đồng bộ 2 chiều **iOS ↔ Android** bằng **Flutter + Supabase** (Fresh Pastel UI, song ngữ EN / VI, hỗ trợ `đ / VNĐ` và `$ / USD`).

## Tính năng chính
- **Chia đều siêu tốc (< 5 giây):** Nhập tổng tiền + nhóm/số người → ra ngay kết quả & VietQR.
- **Scan hóa đơn AI OCR (Gemini 2.5 Flash) hoặc nhập tay:** Kèm thanh đối chiếu tổng tự động (`computedGrandTotal` vs `ocrGrandTotal`), input chỉ nhận số live-format (`1.000` / ATM-POS `1.00`) và 3 hóa đơn mẫu VN test offline.
- **Gán món siêu tốc:** Chọn người ở thanh trên → chạm liên tiếp vào món, nút `Cả bàn`, stepper `+/-` cho món số lượng > 1, giữ lâu để multi-select nhóm con, cảnh báo món chưa gán.
- **Xử lý chuẩn hóa đơn VN & Quốc tế:** Pro-rata VAT / phí phục vụ / giảm giá toàn bill, tùy chọn tiền ship `Chia đều` hoặc `Theo tỷ lệ`, làm tròn (`Không` / `Làm tròn lên`) hiển thị rõ chênh lệch, hỗ trợ `đ / VNĐ` và `$ / USD`.
- **Quản lý bill tiện lợi:** Thanh search trên AppBar (tên bill không dấu, ngày `DD/MM/YY`, thành viên, món), vuốt trái để `Archive` / `Restore` / `Delete`, tab `Archived` & sắp xếp ưu tiên `Pending > Settled > Archived`.
- **VietQR động 100% offline (EMVCo NAPAS 247):** Tự sinh chuỗi TLV + bỏ dấu tiếng Việt + `CRC16-CCITT-FALSE`, hỗ trợ 32 ngân hàng VN.
- **Xuất ảnh PNG chia sẻ Zalo/Messenger:** `SummaryReceiptCard` tổng hợp và `PersonQrCard` động từng người.
- **Local-first + Đồng bộ 2 chiều iOS ↔ Android:** Hoạt động bình thường khi offline; đồng bộ delta Last-Write-Wins + soft-delete khi cấu hình Supabase.

---

## 1. Build App cài lên điện thoại (GitHub Actions & Codemagic)

Repo đã tích hợp sẵn 2 pipeline tự động:

### GitHub Actions ([.github/workflows/build-mobile.yml](.github/workflows/build-mobile.yml))
- Tự động chạy khi push lên `main` hoặc bấm **Actions → Build Mobile Apps → Run workflow**:
  - **Android:** tạo sẵn `mam-android-universal.apk` & `mam-android-arm64.apk` (tải trực tiếp ở mục **Artifacts** của run để cài ngay lên máy Android).
  - **iOS:** tạo sẵn `mam-ios-unsigned.ipa` trên runner `macos-latest` (cài qua AltStore / Sideloadly hoặc ký lại).
- Đẩy tag `v1.0.0` (hoặc tick `create_release` khi chạy tay) để tự phát hành **GitHub Release** đính kèm file `.apk`.

### Codemagic cho iOS TestFlight ([codemagic.yaml](codemagic.yaml))
- Kết nối repo với [Codemagic](https://codemagic.io) (free macOS M2 tier), cấu hình nhóm biến `mam_supabase` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) và App Store Connect `mam_apple` để build & đẩy thẳng lên **TestFlight**.

---

## 2. Kích hoạt Cloud Sync + AI OCR thật (Supabase)

### Cách A — Tự động qua GitHub Actions ([.github/workflows/deploy-supabase.yml](.github/workflows/deploy-supabase.yml))
1. Tạo 1 project mới tại [Supabase Dashboard](https://supabase.com/dashboard) và lấy API key tại [Google AI Studio](https://aistudio.google.com/apikey).
2. Thêm **6 Repository Secrets** trong GitHub (`Settings → Secrets and variables → Actions`):
   - `SUPABASE_ACCESS_TOKEN` (Personal Access Token từ Supabase Account → Access Tokens)
   - `SUPABASE_PROJECT_REF` (mã 20 ký tự của project)
   - `SUPABASE_DB_PASSWORD` (mật khẩu DB khi tạo project)
   - `GEMINI_API_KEY` (API key Gemini 2.5 Flash)
   - `SUPABASE_URL` (`https://<PROJECT_REF>.supabase.co`)
   - `SUPABASE_ANON_KEY` (Publishable / Anon key của project)
3. Chạy **Actions → Deploy Supabase → Run workflow** để đẩy cả 3 migration ([supabase/migrations](supabase/migrations)) + nạp `GEMINI_API_KEY` + deploy Edge Function [scan-bill](supabase/functions/scan-bill/index.ts), sau đó chạy lại **Build Mobile Apps** để nhúng `SUPABASE_URL` & `SUPABASE_ANON_KEY` vào file `.apk` / `.ipa`.

### Cách B — Chạy 1 lệnh tại máy local
```bash
SUPABASE_ACCESS_TOKEN=... \
SUPABASE_PROJECT_REF=... \
SUPABASE_DB_PASSWORD=... \
GEMINI_API_KEY=... \
  ./scripts/deploy-supabase.sh
```

---

## 3. Chạy thử Local (Web / Tests)

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Tài liệu
- Đặc tả MVP & Data Schema: [docs/mvp-spec.md](docs/mvp-spec.md)
- Hệ thống thiết kế Fresh Pastel: [DESIGN.md](DESIGN.md)

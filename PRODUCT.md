# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

- **Primary user (Chủ xị / Host):** Cá nhân đứng ra thanh toán hóa đơn nhóm tại Việt Nam (ăn trưa văn phòng, đi nhậu, lẩu, cà phê, đặt GrabFood/ShopeeFood), dùng đồng thời cả iOS và Android.
- **Secondary recipient (Người nhận ảnh — không cài app):** Bạn bè / đồng nghiệp trong nhóm Zalo hoặc Messenger, chỉ cần xem tấm ảnh tóm tắt (Receipt Card) và quét mã VietQR động để chuyển khoản đúng số tiền mà không phải cài app hay tạo tài khoản.

## Product Purpose

Giúp chủ xị chia xong một hóa đơn nhóm phức tạp (món dùng chung, số lượng nhiều, VAT 8%/10%, phí phục vụ, tiền ship, voucher giảm giá) trong **dưới 45 giây**, xuất ảnh tóm tắt kèm mã VietQR động 100% offline gửi thẳng vào nhóm chat, và theo dõi nhẹ ai đã trả / còn ai chưa đóng — đồng bộ 2 chiều giữa iOS và Android.

## Positioning

- **Single-player tool:** Chỉ 1 người đứng ra trả tiền cần cài app; bạn bè không bị ép tải app hay đăng ký tài khoản.
- **VietQR động 100% offline (EMVCo NAPAS 247):** Tự sinh chuỗi QR kèm sẵn đúng số tiền và nội dung chuyển khoản chuẩn hóa không dấu ngay trên máy, không phụ thuộc API bên thứ 3.
- **Xử lý triệt để "đặc sản" hóa đơn Việt Nam:** Gán món siêu tốc 1 chạm, chia món dùng chung, tách giảm giá theo món vs toàn bill, phân bổ pro-rata VAT/phí phục vụ, chọn chia đều hoặc pro-rata cho tiền ship, làm tròn 1.000đ hiển thị minh bạch chênh lệch, và đối chiếu tổng tự động khi scan OCR.

## Operating Context

- **Môi trường sử dụng thực tế:** Ngay tại bàn ăn đông đúc, quán nhậu ánh sáng yếu/nhiều tạp âm, giờ nghỉ trưa vội vàng, hoặc trong tầng hầm/quán mất sóng di động (cần offline-first 100%).
- **Kênh đầu ra chính:** Ảnh PNG gửi vào nhóm Zalo / Messenger (Receipt Card tổng hợp hoặc thẻ VietQR riêng từng người) để bạn bè quét trực tiếp bằng app ngân hàng VN (VCB, TCB, MB, BIDV, ACB, TPBank, Momo...).
- **Thói quen lặp lại:** Đi ăn lặp lại cùng các nhóm quen (*Team Công ty*, *Hội bạn thân*), cần lưu sẵn STK ngân hàng và danh sách nhóm.

## Capabilities and Constraints

- **Stack hiện hữu:** Flutter (Dart 3) cho iOS + Android (+ Web demo) kết hợp Supabase (PostgreSQL + RLS + Auth 1 tài khoản cá nhân + 1 Edge Function `/scan-bill` gọi Gemini 2.5 Flash).
- **Chế độ cốt lõi:** 6 màn hình chính (`HomeScreen`, `QuickEqualScreen`, `BillInputScreen`, `SplitAssignScreen`, `ResultScreen`, `SettingsScreen`) cùng 2 ảnh xuất ra (`SummaryReceiptCard`, `PersonQrCard`).
- **Yêu cầu bất biến về nghiệp vụ:**
  - Số tiền VNĐ luôn hiển thị rõ ràng, thẳng hàng (tabular figures), dễ đối chiếu.
  - Luôn cảnh báo rõ khi còn món chưa gán, khi tổng OCR bị lệch, và khi làm tròn phát sinh chênh lệch chủ xị bù/dư.
  - Giữ toàn bộ tính năng offline (chia bill, tính toán, sinh VietQR, lưu local) hoạt động không cần mạng.
- **Ngoài phạm vi MVP v1.0:** Chia nhiều người đứng ra trả tiền (multi-payer), đa ngoại tệ, nhắc nợ tự động, phát hành public đa tài khoản.

## Brand Commitments

- **Tên sản phẩm:** **Mâm** (package/slug: `mam`) — ngắn gọn, 1 âm tiết, gợi hình ảnh bàn ăn Việt quây quần.
- **Ngôn ngữ giao diện:** Tiếng Việt có dấu tự nhiên, rõ ràng, súc tích.
- **Hướng thẩm mỹ đã chốt (Standing Preference — Canon):** **Chuẩn Fintech Việt Nam (Canon)** — ngôn ngữ sạch, sắc nét, đáng tin cậy ngang tầm các ứng dụng ngân hàng & tài chính hiện đại (như Techcombank Mobile, Timo, Wise, Apple Wallet), không hiệu ứng trang trí thừa hay bố cục phá cách làm chậm thao tác.
- **Chế độ hiển thị:** Hỗ trợ đầy đủ cả **Chế độ Sáng (Light)** và **Chế độ Tối (Dark)** theo chuẩn thích ứng hệ điều hành (`adaptive` iOS + Android), kèm tùy chọn chuyển đổi nhanh. Ảnh Receipt Card / VietQR xuất ra gửi Zalo luôn giữ nền trắng tương phản cao để quét QR chính xác.

## Evidence on Hand

- Đặc tả MVP và Data Schema: `docs/mvp-spec.md`, `supabase/migrations/001_init.sql`, `app/lib/models/bill_models.dart`.
- Bản dựng Flutter MVP v1.0 đang chạy đầy đủ logic & dữ liệu mẫu demo (Lẩu Haidilao Bitexco, Phê La GrabFood, 3 mẫu OCR hóa đơn VN offline, 32 mã BIN ngân hàng VN).
- Không có ảnh chụp sản phẩm thương mại hay khách hàng bên ngoài (ứng dụng phục vụ cá nhân); mọi dữ liệu hiển thị là dữ liệu demo nội bộ.

## Product Principles

1. **Xong trước khi rời bàn (< 45 giây):** Mọi màn hình tối ưu cho thao tác 1 tay nhanh, giảm số lần mở popup và gõ chữ.
2. **Minh bạch từng đồng:** Mọi con số thuế, giảm giá, tiền ship, món chưa gán và độ lệch làm tròn phải rõ ràng để cả bàn tin tưởng ngay khi nhìn Receipt Card.
3. **Tin cậy khi mất mạng:** Không có mạng vẫn chia bill, tạo VietQR và theo dõi đã trả mượt mà; sync âm thầm khi có kết nối.
4. **Thân quen như app bản địa:** Tuân thủ chuẩn thao tác iOS & Android (`adaptive`), không bày vẽ điều khiển lạ lẫm cản trở tốc độ chia tiền.

## Accessibility & Inclusion

- Tương phản chữ/số tiền rõ ràng ngay cả dưới ánh sáng quán nhậu tối hoặc ngoài trời nắng.
- Vùng chạm đủ lớn (≥ 44–48pt) cho thao tác tap liên tiếp gán món bằng 1 tay.

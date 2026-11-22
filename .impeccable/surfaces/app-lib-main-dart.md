---
version: 1
slug: "app-lib-main-dart"
primary_target: "app/lib/main.dart"
related_targets: ["app/lib/theme/mam_theme.dart","app/lib/screens/home_screen.dart","app/lib/screens/result_screen.dart","app/lib/widgets/receipt_card.dart"]
---

# Surface Brief — Mâm Mobile App (MVP Core Flow)

- **Scope:** Core mobile app (`HomeScreen`, `QuickEqualScreen`, `BillInputScreen`, `SplitAssignScreen`, `ResultScreen`, `SettingsScreen`, `SummaryReceiptCard`, `PersonQrCard`).
- **Visitor mode:** Operate (`adaptive` iOS + Android, plus responsive mobile shell on Web demo).
- **Audience & job:** Single-player Vietnamese host splitting a group meal bill in <45s, generating offline VietQR PNG cards for Zalo/Messenger, and tracking who has paid across iOS & Android.

## Direction contract

- **THESIS:** Deliver Vietnamese fintech clarity at full native craft — unmistakable banking-blue hierarchy, razor-sharp tabular VND alignment, and zero decorative friction — refusing both muddy warm-cream clichés and gimmicky novelty skins.
- **OWN-WORLD:** Crisp cool-mist Light mode (`#F4F6FA` ground, `#FFFFFF` cards, `#E2E8F0` hairlines, `#0066FF` primary banking blue, `#059669` settled emerald) paired with a first-class midnight-slate Dark mode (`#0B0F17` ground, `#131A26` cards, `#232E40` hairlines, `#3B82F6` luminous blue, `#34D399` emerald); exported VietQR Receipt Cards always render on crisp printable white stock for reliable bank-app scanning.
- **STORY:** The host opens Mâm, immediately sees unpaid balance and pending bills, splits a new meal or taps paid in seconds, and shares a trustworthy fintech-grade Receipt Card + dynamic VietQR into Zalo.
- **FIRST VIEWPORT:** Clean native AppBar (`Mâm`, sync pill, quick Light/Dark toggle, Settings), a committed banking-blue Uncollected Balance slab with tabular VND figure and pending count, horizontal status filter pills (`Tất cả`, `Chưa đủ`, `Đã xong`), scannable hairline-bordered bill cards with progress bar and semantic badges, and a thumb-reachable persistent bottom action bar (`Chia đều` + `+ Tạo bill mới`).
- **FORM:** Chuẩn Fintech Việt Nam (Canon, standing exit — Light + Dark adaptive), seed:65cd38d96f1f4f87.
- **FINISH:** unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

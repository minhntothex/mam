# Design System — Mâm (`mam`)

> **Direction:** Chuẩn Fintech Việt Nam (Canon) — Adaptive Light & Dark (`iOS` + `Android` + responsive Web demo)  
> **Mode:** Operate (scanability, native familiarity, tabular precision)  
> **Source of truth in code:** [app/lib/theme/mam_theme.dart](app/lib/theme/mam_theme.dart)

---

## 1. Visual Principles

1. **Earned familiarity:** Native iOS/Android controls (`Material 3` + iOS safe-area/edge-swipe conventions), zero novelty affordances that slow down splitting a bill at the table.
2. **Action-only primary blue:** Banking blue (`#0066FF` Light / `#3B82F6` Dark) is reserved for the Uncollected Balance slab, primary actions, active selections, and key totals — never scattered decoration.
3. **Tabular precision:** Every VND amount, subtotal, delta, and date uses `FontFeature.tabularFigures()` so columns align cleanly without horizontal jitter.
4. **First-class Light & Dark:** Both themes are independently tuned for WCAG AA contrast (`≥ 4.5:1` body/secondary text) — Light for daylight/office lunches, Dark for dimly lit evening hotpot/nhậu tables.
5. **Print-safe Receipt Cards:** Exported PNGs (`SummaryReceiptCard`, `PersonQrCard`) always render on crisp white paper (`MamReceiptColors`) regardless of the active app theme, guaranteeing reliable VietQR scanning from Zalo/Messenger.

---

## 2. Color Tokens (`MamPalette` ThemeExtension)

| Semantic Role | Light Mode | Dark Mode | Usage |
|---|---|---|---|
| `ground` | `#F4F6FA` | `#0B0F17` | Screen scaffold background |
| `surface` | `#FFFFFF` | `#131A26` | Cards, bottom bars, dialogs, sheets |
| `surfaceSubtle` | `#EDF1F7` | `#1C2536` | Secondary pills, progress tracks, dark inputs |
| `border` | `#E2E8F0` | `#243044` | 1px hairline elevation (single elevation mechanism) |
| `ink` | `#0F172A` | `#F8FAFC` | Primary headings, item names, VND amounts |
| `muted` | `#526075` | `#94A3B8` | Metadata, dates, secondary labels |
| `primary` | `#0066FF` | `#3B82F6` | Primary CTA, active links, active states |
| `primarySoft` | `#EBF3FF` | `#172554` | Tonal buttons, OCR banner, bank selector, selected chips |
| `heroBackground` / `onHero` | `#F59E0B` / `#0F172A` | `#B45309` / `#FFFFFF` | Uncollected Balance hero slab (amber-gold) |
| `heroSettled` | `#047857` | `#065F46` | All-settled hero slab |
| `success` / `successSoft` | `#059669` / `#ECFDF5` | `#34D399` / `#064E3B` | `Đã trả`, `Đã xong`, OCR matched |
| `warning` / `warningSoft` | `#B45309` / `#FEF3C7` | `#FBBF24` / `#451A03` | Unassigned items, pending cloud push |
| `danger` / `dangerSoft` | `#DC2626` / `#FEF2F2` | `#F87171` / `#450A0A` | OCR total mismatch, destructive delete, sync error |

### Print-Safe Receipt Palette (`MamReceiptColors`)
- Paper `#FFFFFF`, Subtle `#F4F6FA`, Border `#E2E8F0`, Ink `#0F172A`, Muted `#526075`, Primary `#0066FF`, Success `#059669`.

---

## 3. Typography, Shape & Elevation

- **Font stack:** Native platform system sans (SF Pro on iOS, Roboto on Android) via Flutter defaults — zero external font network dependency for offline reliability.
- **Type hierarchy:**
  - Hero VND amount: `30px`, `w800`, `-0.6` tracking, `tabularFigures`
  - AppBar / Screen title: `19px`, `w700`, `-0.3` tracking
  - Section heading: `15px`, `w700`
  - Card title / VND figure: `15.5px`, `w700`–`w800`, `tabularFigures`
  - Metadata / subtitle: `12–12.5px`, `muted`
- **Radii:** Cards `14px`, Hero slab `16px`, Inputs & Buttons `12px`, Badges `6–8px`, Filter pills `20px`.
- **Elevation:** Single mechanism — crisp `1px` `border` hairline on cards and sticky bars (zero fuzzy drop shadows on content cards).
- **Touch targets:** Minimum `48dp` height on all primary/outlined buttons (`42–48dp` on compact row actions).

---

## 4. Core Component Rules

- **Sticky Bottom Action Bars:** `surface` background + `1px` top `border`, `SafeArea(top: false)`, keeping thumb-reachable primary actions pinned at bottom on `Home`, `QuickEqual`, `BillInput`, `SplitAssign`, and `Result`.
- **Theme Mode Control:** Persisted locally (`ThemeMode.system` default) with 3-way selector (`Hệ thống / Sáng / Tối`) in `SettingsScreen` plus a 1-tap Light/Dark toggle icon in `HomeScreen` AppBar.
- **Responsive Shell:** Full edge-to-edge layout on mobile widths (`≤ 520px`); centered `430px` framed mobile viewport on desktop/web demo screens.

---

## 5. Brand Mark & App Icons

- **Concept:** A shared round Vietnamese dining tray (*mâm*) rendered as a crisp geometric annular ring (`252°`, `#FFFFFF`) with one cleanly detached fair-share wedge (`76°`, mint-emerald `#5EEAD4 → #10B981`, offset `+44 / -44`) inside a Canon fintech blue squircle (`#0A74FF → #004CE6`, `rx = 224/1024`).
- **Vector sources:**
  - [assets/brand/mam-logo.svg](assets/brand/mam-logo.svg) (master squircle)
  - [assets/brand/mam-icon-fullbleed.svg](assets/brand/mam-icon-fullbleed.svg) (iOS AppIcon)
  - [assets/brand/mam-icon-maskable.svg](assets/brand/mam-icon-maskable.svg) (Android / Web PWA maskable)
- **Runtime widget:** [app/lib/widgets/mam_logo.dart](app/lib/widgets/mam_logo.dart) (`MamLogoMark`, `CustomPainter`) used in `HomeScreen` AppBar (`30px`) and print-safe `SummaryReceiptCard` (`20px`) / `PersonQrCard` (`18px`).

# Mâm (`mam`)

Personal single-player bill-splitting app with **offline VietQR**, **AI receipt OCR**, and **two-way Cloud Sync** across iOS, Android, and Web — built with **Flutter** and **Supabase** (Fresh Pastel UI, EN / VI, `đ / VND` & `$ / USD`).

**Live Web PWA (iPhone / Desktop):** [minhntothex.github.io/mam](https://minhntothex.github.io/mam/)  
On iPhone, open in **Safari → Share → Add to Home Screen** for a full-screen standalone app with no Developer Mode or 7-day re-signing required.

---

## Features

- **Quick Equal Split (< 5s):** Enter the total and select a group or headcount to generate per-person totals and VietQR codes immediately.
- **AI Receipt OCR (Gemini 2.5 Flash) & Manual Entry:** Built-in reconciliation bar (`computedGrandTotal` vs. `ocrGrandTotal`), strict numeric live-formatting inputs (`1.000` / ATM-POS `1.00` / `Plain`), and 3 offline Vietnamese demo receipts.
- **Fast Item Assignment:** Pick a person at the top and tap items continuously, assign `Whole Table`, adjust multi-quantity items with `+/-` steppers, long-press to multi-select a subgroup, and catch unassigned items before saving.
- **Vietnamese & Multi-Currency Bill Math:** Pro-rata VAT, service charge, and bill-level discounts; `Flat` or `Pro-rata` shipping split; `None` or `Round up` rounding with explicit rounding delta; scalable `CurrencyRegistry` (`đ / VND` default + `$ / USD`).
- **Search, Archive & Priority Sorting:** Multi-field AppBar search (accent-insensitive title, `DD/MM/YY` date, participant, item, note), swipe-left actions (`Archive` / `Restore` / `Delete` with Undo), dedicated `Archived` tab, and `Pending > Settled > Archived` ordering.
- **100% Offline Dynamic VietQR (EMVCo NAPAS 247):** Generates TLV payloads with ASCII normalization and `CRC16-CCITT-FALSE` checksums across 32 Vietnamese banks.
- **PNG Receipt Export:** High-DPI `SummaryReceiptCard` and per-person `PersonQrCard` ready to share via Zalo, Messenger, or Messages.
- **Local-First + Two-Way Sync:** Works offline out of the box and performs Last-Write-Wins delta sync with soft deletes when signed in to Supabase.

---

## 1. Web PWA Deployment (GitHub Pages)

[.github/workflows/deploy-web.yml](.github/workflows/deploy-web.yml) builds the Flutter Web PWA with live `SUPABASE_URL` & `SUPABASE_ANON_KEY` and publishes to GitHub Pages automatically on pushes to `app/**` or via **Actions → Deploy Web PWA → Run workflow**.

---

## 2. Mobile Builds (GitHub Actions & Codemagic)

### GitHub Actions ([.github/workflows/build-mobile.yml](.github/workflows/build-mobile.yml))

Trigger on push to `main`, `v*` tags, or **Actions → Build Mobile Apps → Run workflow** with the **`Platform to build`** dropdown (`both`, `android`, or `ios`):

- **Android:** Produces `mam-android-universal.apk` and `mam-android-arm64.apk` under the run's **Artifacts** for direct sideloading.
- **iOS:** Produces `mam-ios-unsigned.ipa` on `macos-latest` (for re-signing / sideloading).
- Push a `v*` tag (or check `create_release` on manual dispatch) to attach the APKs to a **GitHub Release**.

### Codemagic for Signed iOS TestFlight ([codemagic.yaml](codemagic.yaml))

Connect this repository to [Codemagic](https://codemagic.io), configure the `mam_supabase` variable group (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) and the `mam_apple` App Store Connect integration, and run `ios-testflight` to build and upload directly to TestFlight.

---

## 3. Cloud Sync & AI OCR Backend (Supabase)

### Option A — GitHub Actions ([.github/workflows/deploy-supabase.yml](.github/workflows/deploy-supabase.yml))

1. Create a project in the [Supabase Dashboard](https://supabase.com/dashboard) and an API key in [Google AI Studio](https://aistudio.google.com/apikey).
2. Add **6 Repository Secrets** under **Settings → Secrets and variables → Actions**:
   - `SUPABASE_ACCESS_TOKEN` — Personal Access Token from Supabase Account → Access Tokens
   - `SUPABASE_PROJECT_REF` — 20-character project reference ID
   - `SUPABASE_DB_PASSWORD` — Database password set for the project
   - `GEMINI_API_KEY` — Gemini 2.5 Flash API key
   - `SUPABASE_URL` — `https://<PROJECT_REF>.supabase.co`
   - `SUPABASE_ANON_KEY` — Project publishable / anon key
3. Run **Actions → Deploy Supabase → Run workflow** to push all 3 migrations in [supabase/migrations](supabase/migrations), set `GEMINI_API_KEY`, and deploy the [scan-bill](supabase/functions/scan-bill/index.ts) Edge Function.

### Option B — One-Command Local Deploy

```bash
SUPABASE_ACCESS_TOKEN=... \
SUPABASE_PROJECT_REF=... \
SUPABASE_DB_PASSWORD=... \
GEMINI_API_KEY=... \
  ./scripts/deploy-supabase.sh
```

---

## 4. Local Development

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Documentation

- MVP Spec & Data Schema: [docs/mvp-spec.md](docs/mvp-spec.md)
- Fresh Pastel Design System: [DESIGN.md](DESIGN.md)

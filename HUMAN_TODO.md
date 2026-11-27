# Human To-Do List — PromptIndo Migration (Firebase → Supabase + Vercel)

Status of target choices:
- **Production Firebase data migration:** Skipped (fresh start)
- **Regions:** Target `ap-south-1` (Mumbai) + Vercel `bom1` *(Live database currently connected in `ap-northeast-1` on project `jchjfdpkmmaxddysylxs` — see note below)*
- **Public domain:** Default generated `*.vercel.app` URL
- **Starter categories:** 8 categories seeded

---

## 1. Supabase Project Setup (`jchjfdpkmmaxddysylxs` Connected)
- [x] Supabase project live (`https://jchjfdpkmmaxddysylxs.supabase.co`).
- [x] Applied `init` (`20261127035743`) & `pg_cron` (`20261127035801`) migrations (all 13 tables with RLS enabled, triggers, RPCs, storage buckets `avatars`/`thumbnails` & policies, `pg_cron` jobs, `pg_net` + `pg_trgm` + `supabase_vault` extensions).
- [x] Seeded all 8 starter categories (`writing`, `coding`, `design-art`, `marketing`, `business`, `education`, `productivity`, `fun`).
- > **Region note:** Project `jchjfdpkmmaxddysylxs` is in `ap-northeast-1` (Tokyo). Either change `"regions": ["bom1"]` in `backend/vercel.json` to `["hnd1"]` to colocate Vercel with Tokyo, **or** create a new Supabase project in `ap-south-1` (Mumbai) and run `supabase db push` + `supabase/seed.sql` there.
- [ ] **Authentication → Providers → Email**: Confirm **Email** provider is enabled and **Confirm email = ON**.
- [ ] **Authentication → Email Templates**: Update **Confirm signup** and **Reset password** templates to show the 6-digit OTP (`{{ .Token }}`).
- [ ] **Authentication → SMTP Settings**: Configure Custom SMTP (Resend, Brevo, Postmark, etc.) — built-in Supabase email is rate-limited for testing only.
- [ ] **Authentication → Providers → Google**: Enable Google provider, paste **Web** OAuth Client ID and Client Secret, and add Android/iOS Client IDs for native ID-token sign-in.
- [ ] **Authentication → URL Configuration**: Set **Site URL** to your deployed `https://<your-app>.vercel.app` URL; keep JWT expiry at `3600` seconds.

## 2. Google Cloud & Firebase (FCM Only)
- [ ] **Google Cloud Console → OAuth 2.0 Clients**:
  - Web client ID (used in Supabase Google provider and Flutter `GOOGLE_WEB_CLIENT_ID`).
  - Android client ID: package name **`promptindo.app`** (exact mixed case) + debug & release SHA-1 fingerprints.
  - iOS client ID (if shipping iOS).
- [ ] **Firebase Console** (keep project **only** for FCM push notifications):
  - Project Settings → Service accounts → Generate new private key (JSON).
  - Base64-encode it for Vercel:
    ```bash
    base64 -w0 service-account.json
    ```
  - Keep `app/android/app/google-services.json` for Android FCM.

## 3. Vercel Backend Deployment (`backend/`)
- [ ] Import the public GitHub repository in Vercel (or run `vercel` inside `backend/` after `vercel login`).
- [ ] Set **Root Directory** = `backend` and **Framework Preset** = `Next.js`.
- [ ] Configure Environment Variables in Vercel (Production & Preview):
  - `SUPABASE_URL` = `https://jchjfdpkmmaxddysylxs.supabase.co` *(or your Mumbai project URL)*
  - `SUPABASE_ANON_KEY` = your project anon/publishable key
  - `SUPABASE_SERVICE_ROLE_KEY` = your project service-role secret key *(Server-only — never expose to Flutter or `NEXT_PUBLIC_*`)*
  - `WEBHOOK_SECRET` = random ≥ 32-byte secret (`openssl rand -hex 32`)
  - `FIREBASE_SERVICE_ACCOUNT_BASE64` = base64 Firebase service-account JSON
  - `SITE_URL` = your deployed `https://<your-app>.vercel.app` URL
- [ ] Deploy and verify `GET https://<your-app>.vercel.app/api/health` returns `{"ok":true,...}`.

## 4. Supabase Vault Secrets (Post-Deploy Webhook Wiring)
- [ ] Run in Supabase SQL Editor after deploying to Vercel (never commit these secrets):
  ```sql
  select vault.create_secret('https://<your-app>.vercel.app', 'api_base_url');
  select vault.create_secret('<SAME_WEBHOOK_SECRET_AS_VERCEL>', 'webhook_secret');
  ```

## 5. Deep Links Verification Files
- [ ] Update `backend/public/.well-known/assetlinks.json` with your Android upload/release signing key SHA-256 fingerprint (`REPLACE_WITH_YOUR_UPLOAD_KEY_SHA256`).
- [ ] Update `backend/public/.well-known/apple-app-site-association` with your Apple Developer `TEAMID` if shipping iOS.
- [ ] Update `app/android/app/src/main/AndroidManifest.xml` host if your deployed Vercel URL differs from `www.promptindo.app`.

## 6. Flutter Build, Admin Promotion & Final Cutover
- [ ] Update `API_BASE_URL`, `SITE_URL`, and `GOOGLE_WEB_CLIENT_ID` in `app/env/dev.json` (already pre-populated with live `SUPABASE_URL` & `SUPABASE_ANON_KEY`, gitignored) and create `app/env/prod.json`.
- [ ] Build Android APK on a machine/runner with ≥ 6–8 GiB RAM (`flutter build apk --debug --dart-define-from-file=env/dev.json` or `--release`).
- [ ] Promote your first admin account:
  ```bash
  cd backend && npm run make-admin -- <email-or-uuid>
  ```
- [ ] Run end-to-end verification on a real device (§12 checklist in migration spec).
- [ ] Only **after** cutover is verified, clean up legacy Firebase Firestore/Functions/Hosting resources and remove `functions/`, `hosting/`, `firestore-tests/`, `firestore.rules`, `storage.rules`.

# Human To-Do List — PromptIndo Migration (Firebase → Supabase + Vercel)

Target choices locked in at start:
- **Production Firebase data migration:** No (fresh start, seed starter categories only)
- **Regions:** Supabase `ap-south-1` (Mumbai) + Vercel `bom1` (Mumbai)
- **Public domain:** Default generated `*.vercel.app` URL
- **Starter categories:** Writing, Coding, Design & Art, Marketing, Business, Education, Productivity, Fun

> Note: An existing Supabase project `Promptindo` (`jchjfdpkmmaxddysylxs`) was detected in `ap-northeast-1`. If you want strict Mumbai latency matching `bom1`, create a new Supabase project in `ap-south-1` and link it; otherwise use the existing project and set Vercel region to `hnd1`.

---

## 1. Supabase Project Setup
- [ ] Confirm or create Supabase project in **`ap-south-1` (Mumbai)**.
- [ ] Link and push migrations from repo root:
  ```bash
  supabase link --project-ref <YOUR_PROJECT_REF>
  supabase db push
  ```
- [ ] Seed starter categories (run `supabase/seed.sql` via SQL Editor or `psql` if not auto-seeded on remote):
  - Writing (`✍️`), Coding (`💻`), Design & Art (`🎨`), Marketing (`📣`), Business (`💼`), Education (`🎓`), Productivity (`⚡`), Fun (`🎮`).
- [ ] **Database → Extensions**: verify `pg_cron`, `pg_net`, `pg_trgm`, `supabase_vault` (`vault`) are enabled.
- [ ] **Database → Replication / Realtime**: confirm `notifications`, `comments`, `prompts`, `profiles` are enabled in `supabase_realtime`.
- [ ] **Authentication → Providers → Email**:
  - Enable **Email** provider and keep **Confirm email = ON**.
- [ ] **Authentication → Email Templates**:
  - Update **Confirm signup** and **Reset password** templates to display the 6-digit OTP code (`{{ .Token }}`).
- [ ] **Authentication → SMTP Settings**:
  - Configure Custom SMTP (e.g., Resend, Brevo, Postmark) — Supabase's built-in mailer is strictly rate-limited for testing only.
- [ ] **Authentication → Providers → Google**:
  - Enable Google provider, paste **Web** OAuth Client ID and Client Secret.
  - Add Android & iOS OAuth Client IDs to authorized client IDs if using native ID-token sign-in.
- [ ] **Authentication → URL Configuration**:
  - Set **Site URL** to your deployed `https://<your-app>.vercel.app` URL.
  - Keep JWT expiry at default (`3600` seconds).

## 2. Google Cloud & Firebase (FCM Only)
- [ ] **Google Cloud Console → OAuth 2.0 Clients**:
  - Web client ID (used in Supabase Google provider and Flutter `GOOGLE_WEB_CLIENT_ID`).
  - Android client ID: package name **`Com.promptindo.ai`** (exact mixed case) + debug & release SHA-1 fingerprints.
  - iOS client ID (if shipping iOS).
- [ ] **Firebase Console** (keep project **only** for FCM push notifications):
  - Project Settings → Service accounts → Generate new private key (JSON).
  - Base64-encode the JSON for Vercel (`FIREBASE_SERVICE_ACCOUNT_BASE64`):
    ```bash
    base64 -w0 service-account.json
    ```
  - Keep `app/android/app/google-services.json` in place for Android FCM.

## 3. Vercel Backend Deployment (`backend/`)
- [ ] Run `vercel login` (or import repo in Vercel Dashboard).
- [ ] Set **Root Directory** = `backend`, **Framework Preset** = `Next.js`, **Function Region** = `bom1` (Mumbai, matching `ap-south-1`).
- [ ] Configure Environment Variables in Vercel (Production & Preview):
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY` *(Server-only secret — never expose to Flutter or `NEXT_PUBLIC_*`)*
  - `WEBHOOK_SECRET` *(Random ≥ 32-byte hex/base64 secret, e.g. `openssl rand -hex 32`)*
  - `FIREBASE_SERVICE_ACCOUNT_BASE64` *(Base64 Firebase service-account JSON for FCM)*
  - `SITE_URL` *(Your `https://<your-app>.vercel.app` URL)*
- [ ] Deploy and verify `GET https://<your-app>.vercel.app/api/health` returns `{ "ok": true, ... }`.

## 4. Supabase Vault Secrets (Post-Deploy Webhook Wiring)
- [ ] In Supabase SQL Editor, store the Vault secrets used by `public.call_webhook()` (never commit these values):
  ```sql
  select vault.create_secret('https://<your-app>.vercel.app', 'api_base_url');
  select vault.create_secret('<SAME_WEBHOOK_SECRET_AS_VERCEL>', 'webhook_secret');
  ```

## 5. Deep Links Verification Files
- [ ] Update `backend/public/.well-known/assetlinks.json` with your Android upload/release signing key SHA-256 fingerprint (`REPLACE_WITH_YOUR_UPLOAD_KEY_SHA256`).
- [ ] Update `backend/public/.well-known/apple-app-site-association` with your Apple Developer `TEAMID` if shipping iOS.

## 6. Flutter Release Config & Cutover
- [ ] Create `app/env/dev.json` and `app/env/prod.json` from `app/env/example.json` (gitignored) with real `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_BASE_URL`, `GOOGLE_WEB_CLIENT_ID`, and `SITE_URL`.
- [ ] Promote your first admin account using the helper script:
  ```bash
  cd backend && npm run make-admin -- <email-or-uuid>
  ```
- [ ] Complete end-to-end verification on a real Android/iOS device (see §12 checklist in migration plan).
- [ ] Only **after** cutover is verified, clean up legacy Firebase Firestore/Functions/Hosting resources.

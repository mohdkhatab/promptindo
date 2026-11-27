# PromptIndo

A social AI-prompt sharing platform — discover, copy, save, like, remix, comment, follow, and publish prompts — built on **Flutter + Riverpod**, **Supabase** (Auth, Postgres + RLS + triggers + RPC + Realtime + Storage + `pg_cron`), and **Next.js on Vercel** (admin moderation, account deletion, FCM push webhooks, and public prompt/deep-link pages).

---

## 1. Architecture

```text
                  ┌────────────────────────── Supabase ──────────────────────────────────┐
 Flutter app ────►│ Auth (JWT + OTP) · Postgres + RLS + triggers + RPC · Storage         │
 (supabase_flutter│ Realtime · pg_cron (trending + view cleanup)                         │
  direct, ~95%)   │                                                                      │
        │         │   DB webhooks (pg_net + Vault) ──┐                                   │
        │         └──────────────────────────────────┼───────────────────────────────────┘
        │                                            ▼
        │  HTTPS + Supabase JWT      ┌─────────────────────────────┐  service_role   ┌────────────┐
        └───────────────────────────►│ Next.js on Vercel (`bom1`)  │ ───────────────►│ Supabase   │
          (account delete, admin)    │ Route Handlers (Node.js)    │  firebase-admin │ Admin APIs │
                                     │ + public site & .well-known │ ───────────────►│ FCM (push) │
                                     └─────────────────────────────┘                 └────────────┘
```

- **Hot path (`~95%` of traffic):** Flutter connects directly to Supabase via `supabase_flutter` using the anon/publishable key, protected by Postgres RLS and column-level `GRANT`s.
- **Trusted server (`backend/`):** Next.js App Router Route Handlers (`runtime = "nodejs"`) handle privileged operations requiring `SUPABASE_SERVICE_ROLE_KEY`, `WEBHOOK_SECRET`, or `FIREBASE_SERVICE_ACCOUNT_BASE64` (FCM push notifications, storage deletion webhooks, full account deletion, and admin moderation).
- **FCM only on Firebase:** Firebase is retained solely for Android/iOS push delivery (`firebase_core` + `firebase_messaging` in Flutter, `firebase-admin/messaging` in `backend/`).

---

## 2. Repository Layout

```text
promptindo/
├── app/                     # Flutter + Riverpod app (Clean Architecture)
│   ├── env/                 # --dart-define-from-file templates (*.example.json)
│   ├── lib/
│   │   ├── core/            # config, providers, error mapper, theme, widgets, deep links, FCM
│   │   └── features/        # auth, home, explore, prompts, categories, comments,
│   │                        # bookmarks, notifications, profile, settings, shell
│   └── test/                # Flutter unit tests
├── backend/                 # Next.js 16 App Router API + public site (Vercel Root Directory)
│   ├── public/              # robots.txt, manifest.json, .well-known/{assetlinks.json,apple-app-site-association}
│   ├── src/
│   │   ├── app/(site)/      # /, /privacy, /terms, /p/[id] (ISR revalidate=60 + OG tags)
│   │   ├── app/api/         # health, webhooks/*, account/delete, admin/*
│   │   ├── lib/             # env, supabase-admin, fcm, auth, audit, http, schemas, pagination
│   │   └── __tests__/       # Vitest API & security suite
│   ├── vercel.json          # Function region configuration
│   └── .env.example
├── supabase/                # Database schema, triggers, RLS, RPCs, pg_cron, seed, and tests
│   ├── migrations/
│   │   ├── 20261127000001_init.sql
│   │   └── 20261127000002_pg_cron.sql
│   ├── seed.sql             # 8 starter categories
│   └── tests/               # db_tests.mjs (29 RLS/trigger suites) + perf_gate.mjs (50k/500k EXPLAIN)
├── scripts/
│   └── make-admin.ts        # Promote/demote admin via Supabase app_metadata + profiles.role
├── HUMAN_TODO.md            # Manual setup & cutover checklist
└── MIGRATION_LOG.md         # Phase-by-phase engineering & verification log
```

> Legacy Firebase files (`functions/`, `hosting/`, `firestore.rules`, `storage.rules`, `firestore-tests/`, `firebase.json`) are intentionally preserved until production cutover verification is complete.

---

## 3. Environment Variables

### Backend (`backend/.env.local` locally / Vercel Project Settings)
Copy `backend/.env.example`:
- `SUPABASE_URL` — Project URL (`https://<ref>.supabase.co`)
- `SUPABASE_ANON_KEY` — Supabase anon/publishable key
- `SUPABASE_SERVICE_ROLE_KEY` — **Server-only** Supabase service-role secret key (never expose to Flutter or `NEXT_PUBLIC_*`)
- `WEBHOOK_SECRET` — Random secret (`>= 32` bytes, e.g. `openssl rand -hex 32`) matching Vault `webhook_secret`
- `FIREBASE_SERVICE_ACCOUNT_BASE64` — Base64-encoded Firebase service-account JSON (FCM only)
- `SITE_URL` — Public site URL (e.g. `https://www.promptindo.app`)

### Flutter (`app/env/dev.json`, gitignored)
Copy `app/env/dev.example.json`:
```json
{
  "SUPABASE_URL": "https://<ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon-or-publishable-key>",
  "API_BASE_URL": "https://<your-app>.vercel.app",
  "GOOGLE_WEB_CLIENT_ID": "<web-oauth-client-id>.apps.googleusercontent.com",
  "SITE_URL": "https://<your-app>.vercel.app"
}
```

---

## 4. Setup, Run & Test

### Database (`supabase/`)
```bash
# Link to your Supabase project and push migrations
supabase link --project-ref <YOUR_PROJECT_REF>
supabase db push

# Run local PostgreSQL 16 verification suites (requires Postgres 16)
node --test supabase/tests/db_tests.mjs
node supabase/tests/perf_gate.mjs
```

### Backend (`backend/`)
```bash
cd backend
npm ci
cp .env.example .env.local   # fill in real values

npm run dev                  # local server on http://localhost:3000
npm run lint                 # ESLint
npx tsc --noEmit             # TypeScript strict check
npm test                     # Vitest API & security tests
npm run build                # Next.js production build
```

### Flutter App (`app/`)
```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env/dev.json
flutter build apk --release --dart-define-from-file=env/prod.json
```

---

## 5. Deploy Backend to Vercel

1. Push this repository to GitHub.
2. In Vercel, import the repository with **Root Directory** = `backend` and **Framework Preset** = `Next.js` (or run `vercel` inside `backend/`).
3. Set all environment variables from `backend/.env.example`.
4. Deploy and check `GET https://<your-app>.vercel.app/api/health`.
5. Add Supabase Vault secrets in the Supabase SQL Editor so DB triggers can call push/storage webhooks:
   ```sql
   select vault.create_secret('https://<your-app>.vercel.app', 'api_base_url');
   select vault.create_secret('<SAME_WEBHOOK_SECRET_AS_VERCEL>', 'webhook_secret');
   ```

---

## 6. Admin & Moderation

PromptIndo has no in-app admin panel. Admin actions require a Supabase user whose JWT carries `app_metadata.role = "admin"` and whose `public.profiles` row has `role = 'admin'` and `status = 'active'`.

### Grant admin role
Requires `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in `backend/.env.local` (or exported in the shell):
```bash
cd backend
npm run make-admin -- user@example.com
# or revoke:
npm run make-admin -- user@example.com --revoke
```

### Admin API `curl` examples
Obtain an admin user's access token (`$ADMIN_JWT`) via Supabase Auth, then call `https://<your-app>.vercel.app`:

```bash
# List pending reports
curl -sS -H "Authorization: Bearer $ADMIN_JWT" \
  "https://<your-app>.vercel.app/api/admin/reports?status=pending&limit=50"

# Resolve a report (also sends report_resolved notification + FCM push)
curl -sS -X PATCH -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{"status":"resolved","resolution_note":"Removed violating prompt"}' \
  "https://<your-app>.vercel.app/api/admin/reports/<REPORT_UUID>"

# Ban / unban a user
curl -sS -X PATCH -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{"status":"banned","notes":"Spam"}' \
  "https://<your-app>.vercel.app/api/admin/users/<USER_UUID>/status"

# Feature / unfeature a prompt
curl -sS -X PATCH -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{"featured":true,"notes":"Editor pick"}' \
  "https://<your-app>.vercel.app/api/admin/prompts/<PROMPT_UUID>/featured"

# Hide or remove a prompt / hard-delete a prompt
curl -sS -X PATCH -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{"status":"hidden","notes":"Under review"}' \
  "https://<your-app>.vercel.app/api/admin/prompts/<PROMPT_UUID>/status"

curl -sS -X DELETE -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{"notes":"Policy violation"}' \
  "https://<your-app>.vercel.app/api/admin/prompts/<PROMPT_UUID>"

# Soft-delete a comment
curl -sS -X DELETE -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{"notes":"Abusive comment"}' \
  "https://<your-app>.vercel.app/api/admin/comments/<COMMENT_UUID>"

# Create / update / delete category
curl -sS -X POST -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{"name":"Audio","slug":"audio","icon":"🎵","description":"Music and voice prompts","sort_order":9}' \
  "https://<your-app>.vercel.app/api/admin/categories"

# Inspect audit log
curl -sS -H "Authorization: Bearer $ADMIN_JWT" \
  "https://<your-app>.vercel.app/api/admin/audit?limit=50"
```

# PromptIndo Migration Log (Firebase → Supabase + Next.js on Vercel)

## Phase 0 — Setup & Decisions
- **Date:** 2026-11-27
- **Answers locked in:**
  1. **Production Firebase data migration:** No — skip Phase 4, start fresh and seed starter categories.
  2. **Regions:** Supabase `ap-south-1` (Mumbai) + Vercel `bom1`. *(Note: Existing Supabase project `Promptindo` ref `jchjfdpkmmaxddysylxs` in `ap-northeast-1` was linked/detected via MCP and has been populated with the schema + 8 starter categories; see `HUMAN_TODO.md` if migrating to a dedicated `ap-south-1` project or switching `backend/vercel.json` to `hnd1`.)*
  3. **Public domain:** Default generated `*.vercel.app` URL.
  4. **Starter categories:** Writing (`✍️`), Coding (`💻`), Design & Art (`🎨`), Marketing (`📣`), Business (`💼`), Education (`🎓`), Productivity (`⚡`), Fun (`🎮`).
- **Environment notes:**
  - Docker is unavailable on this host (`supabase start` unavailable), so local database tests and the 50k/500k EXPLAIN gate ran against PostgreSQL 16.15 (`promptindo_test`) with stub schemas in `supabase/tests/stub_supabase.sql`.
  - Root `.gitignore` originally listed `lib/`, which matched `backend/src/lib/` and `app/lib/`. Fixed to `functions/lib/` and added `.env*` + `app/env/*.json` exclusions.

---

## Phase 1 — Supabase Database (`supabase/`)
- **Migrations & Seed:**
  - `supabase/migrations/20261127000001_init.sql`: 13 tables, partial/GIN/trigram indexes, triggers (auth profile provisioning, denormalized author fields, atomic counters, notifications, report 1h dedupe/validation), RPCs (`copy_prompt`, `record_view`, `register_fcm_token`, `unregister_fcm_token`, `search_prompts`, `prompts_by_tag`, `recompute_trending`), RLS on all 13 tables, column-level `GRANT`s, `supabase_realtime`, `avatars`/`thumbnails` buckets & policies, and guarded `pg_net` extension enablement.
  - `supabase/migrations/20261127000002_pg_cron.sql`: `pg_cron` extension + `recompute-trending` (`*/15 * * * *`) and `cleanup-prompt-views` (`17 * * * *`).
  - `supabase/seed.sql`: 8 starter categories (`on conflict (slug) do nothing`).
- **Performance Discovery & Fix:**
  - Under RLS on `prompts`, PostgreSQL treats `~~*` (`ILIKE`) and `@>` as non-leakproof (`proleakproof = f`), blocking GIN index usage behind the RLS security barrier (61.8 ms on rare tags, 163.9 ms on `search_prompts`). Converting `search_prompts` to pure `language sql` `SECURITY DEFINER set search_path = ''` (hardcoding `status = 'active' and visibility = 'public'`) and adding `public.prompts_by_tag` RPC enabled GIN `Bitmap Index Scan`s.
- **Verification:**
  - `node --test supabase/tests/db_tests.mjs`: **29 / 29 tests passed** (porting all `firestore.rules.test.js` cases + §5.5 + §11 checks).
  - `node supabase/tests/perf_gate.mjs` (50,000 prompts, 500,000 likes, 50,000 comments, 100,000 notifications): all 10 queries passed `< 20 ms` (**0.091 ms – 7.974 ms**, zero sequential scans).
- **Live Supabase Database (`jchjfdpkmmaxddysylxs`) Connected:**
  - Applied `init` (`20261127035743`) and `pg_cron` (`20261127035801`) migrations + seeded all 8 categories.
  - Verified all 13 public tables have `rowsecurity = true`, 2 buckets (`avatars`, `thumbnails`) + 8 storage policies, 4 extensions (`pg_cron`, `pg_net`, `pg_trgm`, `supabase_vault`), and 2 scheduled `pg_cron` jobs.

---

## Phase 2 — Next.js Backend & API (`backend/`, `scripts/make-admin.ts`)
- Built all 13+ API routes in `backend/src/app/api/` (`runtime = "nodejs"`, `dynamic = "force-dynamic"`, async Next 16 `params`, `.strict()` Zod schemas, module-scope singletons, structured JSON logging without PII/tokens).
- Built public pages `/`, `/privacy`, `/terms`, `/p/[id]` (`revalidate = 60` + OG/Twitter metadata) and `backend/public/.well-known/*` headers in `next.config.ts`.
- Built `scripts/make-admin.ts` (`npm run make-admin -- <email|uuid>`).
- **Sentinel Security Audit & Fixes:**
  - Fixed Medium finding in `backend/src/app/api/webhooks/prompt-deleted/route.ts`: hardened `isSafeThumbnailPath` to reject `%` and iteratively decoded traversal sequences (`%2e%2e`, `%2f`, `%5c`, `%00`) with Vitest regression coverage.
  - Fixed Low finding in `backend/src/lib/pagination.ts`: tightened `cursorSchema.created_at` to `z.string().datetime({ offset: true })` and normalized via `new Date(...).toISOString()`.
  - Fixed Low finding in `supabase/migrations/20261127000001_init.sql`: added `name !~ '(^|/)\.\.(/|$)'` and extension checks to storage `INSERT`/`UPDATE` policies.
- **Verification:** `npm run lint` (0 warnings/errors), `npx tsc --noEmit` (0 errors), `npm test` (**29 / 29 passed** across 4 test files), `npm run build` (succeeded), `npm audit --omit=dev` (0 vulnerabilities).

---

## Phase 3 — Flutter App (`app/`)
- Removed `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_app_check` from `app/pubspec.yaml`; kept `firebase_core` and `firebase_messaging` for FCM; added `supabase_flutter` (`2.18.3`) and `http` (`1.6.0`).
- Added `AppConfig` (`--dart-define-from-file`), `app/env/*.example.json`, `backend_providers.dart`, `value_utils.dart`, `SupabaseErrorMapper`, keyset pagination with UTC `Z` timestamps, and all `supabase_*_repository.dart` implementations.
- **Permitted UI additions (§7.2):**
  - `VerifyEmailScreen`: 6-digit email OTP verification field + existing resend cooldown.
  - `ForgotPasswordScreen`: 2nd step with 6-digit recovery OTP + new password.
- Updated `AndroidManifest.xml` deep-link host to `promptindo.vercel.app` (kept `applicationId = "Com.promptindo.ai"` unchanged); updated share URLs to use `AppConfig.siteUrl`. Old Firebase Hosting links (`prompindo.web.app`, `prompindo.firebaseapp.com`) will no longer deep-link once cutover occurs.
- Checked `PromptCard` (`prompt_card.dart`) & `FeaturedCard`: neither displays or copies `prompt_content`, so list queries omit `prompt_content` (`SupabasePromptRepository.listColumns`).
- **Verification:**
  - `flutter analyze`: **No issues found!**
  - `flutter test`: **19 / 19 passed** (`value_utils_test.dart`, `supabase_error_mapper_test.dart`, `prompt_repository_helpers_test.dart`).
  - Forbidden Firebase import grep: clean (zero matches).
  - **Could not complete locally:** `flutter build apk --debug` — the Gradle daemon (`-Xmx8G` in `android/gradle.properties`) was OOM-killed on this host (3.8 GiB RAM). Kept `gradle.properties` unchanged; APK build should be run on a machine/CI runner with ≥ 6–8 GiB RAM (or lower `org.gradle.jvmargs`).

---

## Baseline Bugs Status (§1)
1. **Fixed (Bug #1):** FCM token is now persisted via `register_fcm_token` RPC after sign-in and on `onTokenRefresh`, and removed via `unregister_fcm_token` on sign-out.
2. **Fixed (Bug #2):** `Report.fromMap` default status changed from `'open'` to `'pending'` and `SupabaseReportRepository.submitReport` inserts `status = 'pending'`.
3. **Fixed (Bug #3):** `reports_read` RLS allows `reporter_id = auth.uid()` so `fetchMyReports` succeeds for normal users.
4. **Fixed (Bug #4):** `profiles_username_lower_key` unique constraint on `username_lower` + atomic `handle_new_user()` retry loop eliminates the username race.
5. **Fixed (Bug #5):** `prompts_after_update_category` trigger keeps `categories.prompt_count` accurate when a prompt's category changes.
6. **Fixed (Bug #6):** `profiles_after_update` trigger propagates `username`/`avatar_url` changes to `prompts` and `comments`.
7. **Product decision (Bug #7):** `unlisted` prompts remain restricted to the creator + admins in `prompts_read` RLS (matching Firestore parity). Change `prompts_read` if unlisted links should be public by direct URL.
8. **Product decision (Bug #8):** `follows_read` RLS remains scoped to `follower_id = auth.uid() or followed_id = auth.uid()` (matching Firestore parity). Change `follows_read` to `using (true)` if public follower/following lists are desired.

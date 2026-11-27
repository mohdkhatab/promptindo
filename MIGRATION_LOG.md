# PromptIndo Migration Log (Firebase → Supabase + Next.js on Vercel)

## Phase 0 — Setup & Decisions
- **Date:** 2026-11-27
- **Answers locked in:**
  1. **Production Firebase data migration:** No — skip Phase 4, start fresh and seed starter categories.
  2. **Regions:** Supabase `ap-south-1` (Mumbai) + Vercel `bom1`. *(Note: An existing Supabase project `Promptindo` ref `jchjfdpkmmaxddysylxs` in `ap-northeast-1` was observed via MCP; left untouched — documented region choice in `HUMAN_TODO.md`.)*
  3. **Public domain:** Default generated `*.vercel.app` URL.
  4. **Starter categories:** Writing, Coding, Design & Art, Marketing, Business, Education, Productivity, Fun (each with an emoji icon).
- **Environment notes:**
  - Docker is not installed on this host (`supabase start` unavailable), so Phase 1 migrations, RLS tests, and the 50k/500k `EXPLAIN (ANALYZE, BUFFERS)` performance gate are validated against local PostgreSQL 16.15 with Supabase stub schemas (`auth`, `storage`, `net`, `vault`, `cron`, `extensions`), matching §4.2.
  - `backend/` initialized with Next.js 16.4.6 (App Router, TypeScript) and `supabase/` initialized with `supabase init`.

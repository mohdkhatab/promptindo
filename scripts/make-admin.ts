/**
 * CLI helper to promote a user to admin via Supabase Auth `app_metadata.role`
 * and `public.profiles.role`.
 *
 * Usage (from `backend/`):
 *   npm run make-admin -- <email|uuid>
 *
 * Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in environment.
 */
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type * as SupabaseJs from "../backend/node_modules/@supabase/supabase-js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRequire = createRequire(
  path.resolve(__dirname, "../backend/package.json"),
);
const { createClient } = backendRequire(
  "@supabase/supabase-js",
) as typeof SupabaseJs;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function main() {
  const target = process.argv[2]?.trim();
  if (!target) {
    console.error("Usage: npm run make-admin -- <email|uuid>");
    process.exit(1);
  }

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceKey) {
    console.error(
      "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment.",
    );
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let userId: string | null = null;
  let existingAppMeta: Record<string, unknown> = {};

  if (UUID_RE.test(target)) {
    const { data, error } = await supabase.auth.admin.getUserById(target);
    if (error || !data?.user) {
      console.error(`User not found for UUID: ${target}`);
      process.exit(1);
    }
    userId = data.user.id;
    existingAppMeta =
      (data.user.app_metadata as Record<string, unknown> | undefined) ?? {};
  } else if (EMAIL_RE.test(target)) {
    const normalized = target.toLowerCase();
    let page = 1;
    const perPage = 200;

    for (;;) {
      const { data, error } = await supabase.auth.admin.listUsers({
        page,
        perPage,
      });
      if (error) {
        console.error(`Failed to list users: ${error.message}`);
        process.exit(1);
      }
      const match = data.users.find(
        (u) => u.email?.toLowerCase() === normalized,
      );
      if (match) {
        userId = match.id;
        existingAppMeta =
          (match.app_metadata as Record<string, unknown> | undefined) ?? {};
        break;
      }
      if (data.users.length < perPage) break;
      page += 1;
    }

    if (!userId) {
      console.error(`User not found for email: ${target}`);
      process.exit(1);
    }
  } else {
    console.error("Argument must be a valid email address or UUID.");
    process.exit(1);
  }

  const { error: authErr } = await supabase.auth.admin.updateUserById(userId, {
    app_metadata: {
      ...existingAppMeta,
      role: "admin",
    },
  });
  if (authErr) {
    console.error(`Failed to update auth app_metadata: ${authErr.message}`);
    process.exit(1);
  }

  const { error: profileErr } = await supabase
    .from("profiles")
    .update({ role: "admin" })
    .eq("id", userId);
  if (profileErr) {
    console.error(`Failed to update profiles.role: ${profileErr.message}`);
    process.exit(1);
  }

  console.log(`Promoted user ${userId} to admin.`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});

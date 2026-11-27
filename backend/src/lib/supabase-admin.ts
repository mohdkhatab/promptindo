import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { getEnv, getPublicEnv } from "./env";

let adminClient: SupabaseClient | null = null;
let anonClient: SupabaseClient | null = null;

/**
 * Module-scope singleton Supabase admin client (service_role).
 * Reused across Fluid compute invocations. Never expose to clients.
 */
export function getSupabaseAdmin(): SupabaseClient {
  if (adminClient && process.env.NODE_ENV !== "test") {
    return adminClient;
  }

  const env = getEnv();
  adminClient = createClient(
    env.SUPABASE_URL,
    env.SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    },
  );
  return adminClient;
}

/**
 * Module-scope singleton Supabase anon client for public server rendering.
 */
export function getSupabaseAnon(): SupabaseClient {
  if (anonClient && process.env.NODE_ENV !== "test") {
    return anonClient;
  }

  const env = getPublicEnv();
  anonClient = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
  return anonClient;
}

export function resetSupabaseClientsForTests(): void {
  adminClient = null;
  anonClient = null;
}

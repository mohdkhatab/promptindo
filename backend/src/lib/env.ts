import { z } from "zod";

const serverEnvSchema = z.object({
  SUPABASE_URL: z.string().url("SUPABASE_URL must be a valid URL"),
  SUPABASE_SERVICE_ROLE_KEY: z
    .string()
    .min(1, "SUPABASE_SERVICE_ROLE_KEY is required"),
  SUPABASE_ANON_KEY: z.string().min(1, "SUPABASE_ANON_KEY is required"),
  WEBHOOK_SECRET: z.string().min(1, "WEBHOOK_SECRET is required"),
  FIREBASE_SERVICE_ACCOUNT_BASE64: z
    .string()
    .optional()
    .default(""),
  SITE_URL: z.string().url("SITE_URL must be a valid URL"),
  // Appwrite media storage (server-only). Optional at boot so non-media
  // routes/tests keep working; media handlers fail clearly when missing.
  APPWRITE_ENDPOINT: z
    .string()
    .url("APPWRITE_ENDPOINT must be a valid URL")
    .optional()
    .default(""),
  APPWRITE_PROJECT_ID: z.string().optional().default(""),
  APPWRITE_BUCKET_ID: z.string().optional().default(""),
  APPWRITE_API_KEY: z.string().optional().default(""),
});

const publicEnvSchema = z.object({
  SUPABASE_URL: z.string().url("SUPABASE_URL must be a valid URL"),
  SUPABASE_ANON_KEY: z.string().min(1, "SUPABASE_ANON_KEY is required"),
  SITE_URL: z
    .string()
    .url()
    .optional()
    .default("https://www.promptindo.app"),
});

export type ServerEnv = z.infer<typeof serverEnvSchema>;
export type PublicEnv = z.infer<typeof publicEnvSchema>;

let cachedServerEnv: ServerEnv | null = null;
let cachedPublicEnv: PublicEnv | null = null;

function formatZodIssues(error: z.ZodError): string {
  return error.issues
    .map((issue) => `${issue.path.join(".") || "env"}: ${issue.message}`)
    .join("; ");
}

/**
 * Validates and returns all server environment variables.
 * Cached at module scope in production; re-evaluated in test environments
 * so unit tests can override process.env cleanly.
 */
export function getEnv(): ServerEnv {
  if (cachedServerEnv && process.env.NODE_ENV !== "test") {
    return cachedServerEnv;
  }

  const parsed = serverEnvSchema.safeParse({
    SUPABASE_URL: process.env.SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY,
    WEBHOOK_SECRET: process.env.WEBHOOK_SECRET,
    FIREBASE_SERVICE_ACCOUNT_BASE64:
      process.env.FIREBASE_SERVICE_ACCOUNT_BASE64,
    SITE_URL: process.env.SITE_URL,
    APPWRITE_ENDPOINT: process.env.APPWRITE_ENDPOINT,
    APPWRITE_PROJECT_ID: process.env.APPWRITE_PROJECT_ID,
    APPWRITE_BUCKET_ID: process.env.APPWRITE_BUCKET_ID,
    APPWRITE_API_KEY: process.env.APPWRITE_API_KEY,
  });

  if (!parsed.success) {
    throw new Error(
      `Invalid server environment configuration: ${formatZodIssues(parsed.error)}`,
    );
  }

  cachedServerEnv = parsed.data;
  return parsed.data;
}

/**
 * Validates and returns public-only environment variables needed by (site)
 * server components (no service role or Firebase secret required).
 */
export function getPublicEnv(): PublicEnv {
  if (cachedPublicEnv && process.env.NODE_ENV !== "test") {
    return cachedPublicEnv;
  }

  const parsed = publicEnvSchema.safeParse({
    SUPABASE_URL: process.env.SUPABASE_URL,
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY,
    SITE_URL: process.env.SITE_URL || undefined,
  });

  if (!parsed.success) {
    throw new Error(
      `Invalid public environment configuration: ${formatZodIssues(parsed.error)}`,
    );
  }

  cachedPublicEnv = parsed.data;
  return parsed.data;
}

export function getSiteUrl(): string {
  const raw = process.env.SITE_URL;
  if (raw) {
    const parsed = z.string().url().safeParse(raw);
    if (parsed.success) {
      return parsed.data.replace(/\/+$/, "");
    }
  }
  return "https://www.promptindo.app";
}

export function resetEnvCacheForTests(): void {
  cachedServerEnv = null;
  cachedPublicEnv = null;
}

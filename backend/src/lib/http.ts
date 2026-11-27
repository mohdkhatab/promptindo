import { NextResponse } from "next/server";
import { z } from "zod";

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export interface RequestLogContext {
  userId?: string | null;
}

export function okResponse<T extends Record<string, unknown>>(
  data?: T,
  status = 200,
): NextResponse {
  return NextResponse.json({ ok: true, ...(data ?? {}) }, { status });
}

export function errorResponse(
  status: number,
  code: string,
  message: string,
): NextResponse {
  return NextResponse.json(
    {
      ok: false,
      error: {
        code,
        message,
      },
    },
    { status },
  );
}

/**
 * Emits a single-line structured JSON log for observability without PII,
 * auth tokens, or stack traces.
 */
export function logRequest(entry: {
  route: string;
  method: string;
  status: number;
  ms: number;
  userId?: string | null;
  code?: string;
}): void {
  const payload: Record<string, unknown> = {
    ts: new Date().toISOString(),
    route: entry.route,
    method: entry.method,
    status: entry.status,
    ms: entry.ms,
  };
  if (entry.userId) {
    payload.userId = entry.userId;
  }
  if (entry.code) {
    payload.code = entry.code;
  }
  console.info(JSON.stringify(payload));
}

export async function parseJsonBody<T>(
  req: Request,
  schema: z.ZodType<T>,
): Promise<T> {
  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    throw new ApiError(400, "invalid_json", "Request body must be valid JSON.");
  }

  const parsed = schema.safeParse(raw);
  if (!parsed.success) {
    const first = parsed.error.issues[0];
    const path = first?.path.join(".");
    const detail = first?.message ?? "Invalid request body.";
    throw new ApiError(
      400,
      "validation_error",
      path ? `${path}: ${detail}` : detail,
    );
  }
  return parsed.data;
}

export async function parseOptionalJsonBody<T>(
  req: Request,
  schema: z.ZodType<T>,
): Promise<T | undefined> {
  const text = await req.text();
  if (!text.trim()) {
    return undefined;
  }
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    throw new ApiError(400, "invalid_json", "Request body must be valid JSON.");
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) {
    const first = parsed.error.issues[0];
    const path = first?.path.join(".");
    const detail = first?.message ?? "Invalid request body.";
    throw new ApiError(
      400,
      "validation_error",
      path ? `${path}: ${detail}` : detail,
    );
  }
  return parsed.data;
}

export function parseUuidParam(value: string, label = "id"): string {
  const parsed = z.string().uuid().safeParse(value);
  if (!parsed.success) {
    throw new ApiError(400, "invalid_param", `${label} must be a valid UUID.`);
  }
  return parsed.data;
}

export async function handleRoute(
  route: string,
  req: Request,
  fn: (ctx: RequestLogContext) => Promise<NextResponse>,
): Promise<NextResponse> {
  const startedAt = Date.now();
  const ctx: RequestLogContext = {};

  try {
    const res = await fn(ctx);
    logRequest({
      route,
      method: req.method,
      status: res.status,
      ms: Date.now() - startedAt,
      userId: ctx.userId ?? null,
    });
    return res;
  } catch (err) {
    if (err instanceof ApiError) {
      logRequest({
        route,
        method: req.method,
        status: err.status,
        ms: Date.now() - startedAt,
        userId: ctx.userId ?? null,
        code: err.code,
      });
      return errorResponse(err.status, err.code, err.message);
    }

    if (err instanceof z.ZodError) {
      const msg = err.issues[0]?.message ?? "Validation error.";
      logRequest({
        route,
        method: req.method,
        status: 400,
        ms: Date.now() - startedAt,
        userId: ctx.userId ?? null,
        code: "validation_error",
      });
      return errorResponse(400, "validation_error", msg);
    }

    logRequest({
      route,
      method: req.method,
      status: 500,
      ms: Date.now() - startedAt,
      userId: ctx.userId ?? null,
      code: "internal_error",
    });
    return errorResponse(500, "internal_error", "Internal server error.");
  }
}

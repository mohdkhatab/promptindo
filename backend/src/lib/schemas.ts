import { z } from "zod";

export const uuidSchema = z.string().uuid();

export const notificationTypeSchema = z.enum([
  "like",
  "comment",
  "reply",
  "comment_like",
  "follow",
  "remix",
  "report_resolved",
  "system",
]);

export const pushWebhookSchema = z
  .object({
    id: z.string().uuid(),
    recipient_id: z.string().uuid(),
    actor_id: z.string().uuid().nullable().optional(),
    actor_username: z.string().optional().default(""),
    actor_name: z.string().optional().default(""),
    actor_avatar: z.string().optional().default(""),
    type: notificationTypeSchema,
    prompt_id: z.string().uuid().nullable().optional(),
    comment_id: z.string().uuid().nullable().optional(),
    is_read: z.boolean().optional(),
    data: z.record(z.string(), z.unknown()).optional().default({}),
    created_at: z.string().optional(),
  })
  .strict();

export const promptDeletedWebhookSchema = z
  .object({
    id: z.string().uuid(),
    creator_id: z.string().uuid(),
    thumbnail_path: z.string().min(1).max(512),
  })
  .strict();

export const adminNotesBodySchema = z
  .object({
    notes: z.string().max(1000).optional().default(""),
  })
  .strict();

export const adminUserStatusSchema = z
  .object({
    status: z.enum(["active", "banned"]),
    notes: z.string().max(1000).optional().default(""),
  })
  .strict();

export const adminUserRoleSchema = z
  .object({
    role: z.enum(["user", "admin"]),
  })
  .strict();

export const adminPromptStatusSchema = z
  .object({
    status: z.enum(["active", "hidden", "removed"]),
    notes: z.string().max(1000).optional().default(""),
  })
  .strict();

export const adminPromptFeaturedSchema = z
  .object({
    featured: z.boolean(),
    notes: z.string().max(1000).optional().default(""),
  })
  .strict();

export const adminReportResolveSchema = z
  .object({
    status: z.enum(["resolved", "rejected"]),
    resolution_note: z.string().max(1000).optional().default(""),
  })
  .strict();

export const adminCategorySchema = z
  .object({
    name: z.string().trim().min(1).max(60),
    slug: z
      .string()
      .trim()
      .toLowerCase()
      .regex(
        /^[a-z0-9-]{1,60}$/,
        "slug must contain only lowercase letters, numbers, and hyphens (1-60 chars)",
      ),
    icon: z.string().max(64).optional().default(""),
    description: z.string().max(500).optional().default(""),
    sort_order: z.number().int().min(-10000).max(10000).optional().default(0),
  })
  .strict();

export const adminReportsQuerySchema = z
  .object({
    status: z
      .enum(["pending", "resolved", "rejected", "all"])
      .optional()
      .default("pending"),
    limit: z.coerce.number().int().min(1).max(100).optional().default(50),
    cursor: z.string().min(1).max(200).optional(),
  })
  .strict();

export const adminAuditQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(200).optional().default(50),
    cursor: z.string().min(1).max(200).optional(),
  })
  .strict();

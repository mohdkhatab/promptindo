import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { cache } from "react";
import { z } from "zod";
import { getSiteUrl } from "@/lib/env";
import { getSupabaseAnon } from "@/lib/supabase-admin";

export const revalidate = 60;

interface PublicPrompt {
  id: string;
  title: string;
  description: string;
  creator_username: string;
  creator_avatar: string;
  ai_model: string;
  thumbnail_url: string;
  like_count: number;
  copy_count: number;
  tags: string[];
  created_at: string;
}

const fetchPublicPrompt = cache(
  async (id: string): Promise<PublicPrompt | null> => {
    const parsed = z.string().uuid().safeParse(id);
    if (!parsed.success) {
      return null;
    }

    const { data, error } = await getSupabaseAnon()
      .from("prompts")
      .select(
        "id, title, description, creator_username, creator_avatar, ai_model, thumbnail_url, like_count, copy_count, tags, created_at",
      )
      .eq("id", parsed.data)
      .eq("status", "active")
      .eq("visibility", "public")
      .maybeSingle();

    if (error || !data) {
      return null;
    }

    return data as PublicPrompt;
  },
);

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const prompt = await fetchPublicPrompt(id);
  if (!prompt) {
    return {
      title: "Prompt not found — PromptIndo",
    };
  }

  const siteUrl = getSiteUrl();
  const url = `${siteUrl}/p/${prompt.id}`;
  const description =
    prompt.description ||
    `AI prompt by @${prompt.creator_username || "creator"} on PromptIndo`;

  return {
    title: `${prompt.title} — PromptIndo`,
    description,
    openGraph: {
      title: prompt.title,
      description,
      url,
      type: "article",
      siteName: "PromptIndo",
      images: prompt.thumbnail_url ? [{ url: prompt.thumbnail_url }] : undefined,
    },
    twitter: {
      card: prompt.thumbnail_url ? "summary_large_image" : "summary",
      title: prompt.title,
      description,
      images: prompt.thumbnail_url ? [prompt.thumbnail_url] : undefined,
    },
  };
}

export default async function PublicPromptPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const prompt = await fetchPublicPrompt(id);
  if (!prompt) {
    notFound();
  }

  const siteUrl = getSiteUrl();
  const deepLinkUrl = `${siteUrl}/p/${prompt.id}`;

  return (
    <main className="site-container">
      <div className="prompt-card">
        {prompt.thumbnail_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={prompt.thumbnail_url}
            alt={prompt.title}
            className="prompt-thumb"
          />
        ) : null}

        <div className="prompt-meta">
          <span>@{prompt.creator_username || "creator"}</span>
          {prompt.ai_model ? (
            <span className="prompt-pill">{prompt.ai_model}</span>
          ) : null}
        </div>

        <h1>{prompt.title}</h1>
        {prompt.description ? <p>{prompt.description}</p> : null}

        {prompt.tags && prompt.tags.length > 0 ? (
          <div className="prompt-tags">
            {prompt.tags.map((tag) => (
              <span key={tag} className="prompt-pill">
                #{tag}
              </span>
            ))}
          </div>
        ) : null}

        <div className="prompt-stats site-muted">
          <span>{prompt.like_count} likes</span>
          <span>·</span>
          <span>{prompt.copy_count} copies</span>
        </div>

        <div className="prompt-actions">
          <a href={deepLinkUrl} className="btn-primary">
            Open in app
          </a>
          <Link href="/" className="btn-secondary">
            Get the app
          </Link>
        </div>
      </div>
    </main>
  );
}

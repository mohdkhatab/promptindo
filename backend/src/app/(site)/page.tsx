import type { Metadata } from "next";
import Link from "next/link";

import {
  APP_DOWNLOAD_URL,
  APP_GITHUB_URL,
  APP_NAME,
  APP_RELEASES_URL,
  SUPPORT_EMAIL,
} from "@/lib/site";

export const metadata: Metadata = {
  title: `${APP_NAME} — Discover, share and remix AI prompts`,
  description:
    "PromptIndo is a social AI-prompt library. Discover prompts that work, copy them in one tap, remix them, save favourites, and share your own with images.",
  openGraph: {
    title: `${APP_NAME} — Discover, share and remix AI prompts`,
    description:
      "Discover prompts that work, copy them in one tap, remix them, and share your own with images.",
    type: "website",
  },
};

const features = [
  {
    icon: "🔎",
    title: "Find prompts that work",
    body: "Browse trending prompts, explore categories, and search by title or tag. Every prompt is rated by real likes, copies and views.",
  },
  {
    icon: "⚡",
    title: "Copy in one tap",
    body: "Open a prompt, copy the full text to your clipboard, and paste it into ChatGPT, Claude, Gemini or any other model.",
  },
  {
    icon: "🧬",
    title: "Remix and improve",
    body: "Start from someone else's prompt, adapt it to your workflow, and publish your own version for the community.",
  },
  {
    icon: "🔖",
    title: "Save your favourites",
    body: "Bookmark prompts you want to reuse. Your saved list is always one tap away in the app.",
  },
  {
    icon: "💬",
    title: "Learn from the community",
    body: "Comment, like, follow creators, and see how other people are using AI in their day-to-day work.",
  },
  {
    icon: "🖼️",
    title: "Share prompts with images",
    body: "Add a cover image to your prompt so your post looks as good as the results it produces.",
  },
];

const steps = [
  {
    number: "01",
    title: "Discover",
    body: "Open the app and browse the trending feed or a category that matches your work.",
  },
  {
    number: "02",
    title: "Copy or remix",
    body: "Copy a prompt exactly as written, or remix it into something that fits your own workflow.",
  },
  {
    number: "03",
    title: "Publish",
    body: "Share your best prompts with an image, tags and the model they were written for.",
  },
];

function PhoneMock({
  variant,
  label,
}: {
  variant: "feed" | "detail" | "create";
  label: string;
}) {
  return (
    <div className="shot">
      <div className="phone">
        <div className="phone-notch" />
        <div className="phone-screen">
          <div className="mock-status">
            <span>9:41</span>
            <span>● ● ●</span>
          </div>

          {variant === "feed" && (
            <>
              <div className="mock-brand">PromptIndo</div>
              <div className="mock-search">Search prompts, tags or models</div>
              <div className="mock-tabs">
                <span className="mock-tab active">Trending</span>
                <span className="mock-tab">Latest</span>
              </div>
              <div className="mock-card">
                <div className="mock-image gradient-a" />
                <div className="mock-title">Cinematic product photography</div>
                <div className="mock-meta">@maya · GPT-4o</div>
                <div className="mock-pills">
                  <span>photography</span>
                  <span>midjourney</span>
                </div>
              </div>
              <div className="mock-card">
                <div className="mock-image gradient-b" />
                <div className="mock-title">SQL query builder for analysts</div>
                <div className="mock-meta">@arjun · Claude</div>
              </div>
            </>
          )}

          {variant === "detail" && (
            <>
              <div className="mock-back">← Prompt</div>
              <div className="mock-image gradient-c wide" />
              <div className="mock-title large">
                A calm, high-converting landing page
              </div>
              <div className="mock-meta">@nadia · GPT-4o · 2.4k copies</div>
              <div className="mock-pills">
                <span>marketing</span>
                <span>copywriting</span>
              </div>
              <div className="mock-prompt">
                You are a senior conversion copywriter. Write a landing page for
                {"…"}
              </div>
              <div className="mock-button">Copy prompt</div>
            </>
          )}

          {variant === "create" && (
            <>
              <div className="mock-back">New prompt</div>
              <div className="mock-upload">＋ Add cover image</div>
              <div className="mock-label">TITLE</div>
              <div className="mock-field">Weekly content planner</div>
              <div className="mock-label">PROMPT</div>
              <div className="mock-field tall">
                Act as a social media strategist and build a 7-day content plan
                {"…"}
              </div>
              <div className="mock-button">Publish</div>
            </>
          )}
        </div>
      </div>
      <p className="shot-label">{label}</p>
    </div>
  );
}

export default function HomePage() {
  return (
    <div className="landing">
      <header className="site-nav">
        <Link href="/" className="brand" aria-label={`${APP_NAME} home`}>
          <span className="brand-mark">P</span>
          <span>{APP_NAME}</span>
        </Link>
        <nav className="nav-links" aria-label="Main navigation">
          <a href="#features">Features</a>
          <a href="#screenshots">Screenshots</a>
          <Link href="/privacy">Privacy</Link>
          <Link href="/terms">Terms</Link>
        </nav>
        <a className="nav-cta" href={APP_DOWNLOAD_URL}>
          Download
        </a>
      </header>

      <main>
        <section className="hero">
          <div className="hero-copy">
            <span className="eyebrow">The social AI-prompt library</span>
            <h1>
              Prompts that work.
              <br />
              <span className="gradient-text">Shared by people who use them.</span>
            </h1>
            <p className="hero-sub">
              Discover real prompts for writing, coding, design and business.
              Copy them in one tap, remix them for your workflow, and share your
              own with the community.
            </p>
            <div className="hero-actions">
              <a className="btn-primary btn-large" href={APP_DOWNLOAD_URL}>
                Download the App
              </a>
              <a
                className="btn-secondary btn-large"
                href={APP_RELEASES_URL}
                target="_blank"
                rel="noreferrer"
              >
                View releases
              </a>
            </div>
            <p className="hero-note">
              Free · Android APK · No ads · Built with Flutter
            </p>
          </div>

          <div className="hero-visual" aria-hidden="true">
            <PhoneMock variant="feed" label="Your daily prompt feed" />
            <div className="hero-glow" />
          </div>
        </section>

        <section className="stat-strip" aria-label="PromptIndo at a glance">
          <div>
            <strong>One tap</strong>
            <span>to copy any prompt</span>
          </div>
          <div>
            <strong>Remix</strong>
            <span>make it yours</span>
          </div>
          <div>
            <strong>Community</strong>
            <span>likes, saves and comments</span>
          </div>
          <div>
            <strong>Images</strong>
            <span>show the result, not just the text</span>
          </div>
        </section>

        <section id="features" className="section">
          <div className="section-head">
            <span className="eyebrow">Why PromptIndo</span>
            <h2>Everything you need to build a prompt library that actually gets used.</h2>
          </div>
          <div className="feature-grid">
            {features.map((feature) => (
              <article className="feature-card" key={feature.title}>
                <span className="feature-icon" aria-hidden="true">
                  {feature.icon}
                </span>
                <h3>{feature.title}</h3>
                <p>{feature.body}</p>
              </article>
            ))}
          </div>
        </section>

        <section id="screenshots" className="section screenshots-section">
          <div className="section-head">
            <span className="eyebrow">A look inside</span>
            <h2>Made for browsing, copying and publishing — not for hunting through notes.</h2>
          </div>
          <div className="shots-row">
            <PhoneMock variant="feed" label="Home feed" />
            <PhoneMock variant="detail" label="Prompt details" />
            <PhoneMock variant="create" label="Publish a prompt" />
          </div>
        </section>

        <section className="section how-section">
          <div className="section-head">
            <span className="eyebrow">How it works</span>
            <h2>From discovery to your own published prompt in under a minute.</h2>
          </div>
          <div className="steps">
            {steps.map((step) => (
              <article className="step" key={step.number}>
                <span className="step-number">{step.number}</span>
                <h3>{step.title}</h3>
                <p>{step.body}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="download-section">
          <div>
            <span className="eyebrow">Ready when you are</span>
            <h2>Download PromptIndo and start building your prompt library.</h2>
            <p>
              The latest Android build is published on GitHub Releases. Install
              it directly on your phone — no account required to browse.
            </p>
          </div>
          <div className="download-actions">
            <a className="btn-primary btn-large" href={APP_DOWNLOAD_URL}>
              Download the App
            </a>
            <a
              className="btn-secondary btn-large"
              href={APP_GITHUB_URL}
              target="_blank"
              rel="noreferrer"
            >
              View on GitHub
            </a>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="footer-brand">
          <span className="brand-mark small">P</span>
          <span>{APP_NAME}</span>
        </div>
        <div className="footer-links">
          <Link href="/privacy">Privacy Policy</Link>
          <Link href="/terms">Terms of Service</Link>
          <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>
        </div>
        <p className="site-muted">© 2026 {APP_NAME}. All rights reserved.</p>
      </footer>
    </div>
  );
}

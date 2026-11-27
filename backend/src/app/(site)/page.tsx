import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "PromptIndo",
  description:
    "A social platform for discovering, sharing and remixing AI prompts.",
};

export default function HomePage() {
  return (
    <main className="site-container site-center">
      <h1>PromptIndo</h1>
      <p>
        A social platform for discovering, sharing and remixing AI prompts.
        Prompt pages opened from the app resolve here and deep-link back into
        it.
      </p>
      <div className="site-links">
        <Link href="/privacy">Privacy Policy</Link>
        <Link href="/terms">Terms of Service</Link>
      </div>
      <p className="site-muted site-footer-note">© 2026 PromptIndo</p>
    </main>
  );
}

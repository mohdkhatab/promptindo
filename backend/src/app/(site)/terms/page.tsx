import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "PromptIndo — Terms of Service",
  description: "Terms of Service for PromptIndo",
};

export default function TermsPage() {
  return (
    <main className="site-container">
      <h1>Terms of Service</h1>
      <p className="site-muted">
        Last updated: September 2026 · PromptIndo (&ldquo;the app&rdquo;)
      </p>

      <h2>1. Your account</h2>
      <p>
        You must provide accurate information, keep your credentials secure,
        and be at least 13 years old. One account per person; you are
        responsible for activity under your account.
      </p>

      <h2>2. Your content</h2>
      <p>
        You retain ownership of the prompts, comments and images you post. By
        posting, you grant the app a non-exclusive, worldwide licence to host,
        display and share that content within the service. You confirm your
        content does not infringe anyone&rsquo;s rights.
      </p>

      <h2>3. Acceptable use</h2>
      <ul>
        <li>No spam, scams, malware or deceptive content.</li>
        <li>No harassment, hate speech, or sexual content involving minors.</li>
        <li>
          No scraping, bulk harvesting, or reverse engineering of the service.
        </li>
        <li>No posting content you are not allowed to share.</li>
      </ul>

      <h2>4. Moderation</h2>
      <p>
        Content can be reported by any user. We may remove content, restrict,
        or ban accounts that violate these terms, at our discretion. Decisions
        can be appealed by email.
      </p>

      <h2>5. Service availability</h2>
      <p>
        The service is provided &ldquo;as is&rdquo;. We may modify or
        discontinue features without notice and are not liable for interruptions
        to the extent permitted by law.
      </p>

      <h2>6. Termination</h2>
      <p>
        You may delete your account at any time from Settings. We may suspend or
        terminate accounts that breach these terms.
      </p>

      <h2>7. Changes</h2>
      <p>
        We will update these terms as the product evolves; material changes will
        be announced in the app. Continued use after changes constitutes
        acceptance.
      </p>

      <h2>Contact</h2>
      <p>
        Questions:{" "}
        <a href="mailto:support@promptindo.app">support@promptindo.app</a>
      </p>
    </main>
  );
}

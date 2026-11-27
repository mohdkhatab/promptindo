import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "PromptIndo — Privacy Policy",
  description: "Privacy Policy for PromptIndo",
};

export default function PrivacyPage() {
  return (
    <main className="site-container">
      <h1>Privacy Policy</h1>
      <p className="site-muted">
        Last updated: September 2026 · PromptIndo (&ldquo;the app&rdquo;)
      </p>

      <h2>What we collect</h2>
      <ul>
        <li>
          <strong>Account data:</strong> email address (kept in a private
          Firestore collection), display name, username, biography and optional
          profile photo.
        </li>
        <li>
          <strong>Content you create:</strong> prompts, comments, likes,
          bookmarks and follows.
        </li>
        <li>
          <strong>Device data:</strong> Firebase Cloud Messaging tokens for
          notifications you enable, and App Check / Play Integrity signals used
          solely to prevent abuse.
        </li>
        <li>
          <strong>Usage data:</strong> anonymous view identifiers (randomly
          generated, not tied to your identity) used for trending calculations,
          deduplicated over 24 hours.
        </li>
      </ul>

      <h2>How we use it</h2>
      <p>
        To operate the service: showing your public profile and prompts to
        others, sending notifications you have opted into, moderating reported
        content, and understanding which prompts are trending. We do not sell
        your data and do not use it for advertising.
      </p>

      <h2>Who can see it</h2>
      <p>
        Your <strong>email address is never public</strong> — it is stored
        separately and only readable by you (and administrators handling abuse
        reports). Your name, username, bio, avatar and prompts are public.
        Likes, bookmarks and following lists are visible to signed-in users as
        described in the app.
      </p>

      <h2>Storage &amp; retention</h2>
      <p>
        Data is stored on Google Firebase (Firestore, Cloud Storage,
        Authentication). You can delete your account at any time from{" "}
        <em>Settings → Delete account</em>; this permanently removes your
        profile, prompts, comments and media after the deletion function
        completes.
      </p>

      <h2>Children</h2>
      <p>
        The app is not directed at children under 13 and we do not knowingly
        collect their data.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about this policy:{" "}
        <a href="mailto:privacy@promptindo.app">privacy@promptindo.app</a>
      </p>
    </main>
  );
}

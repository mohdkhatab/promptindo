import type { Metadata } from "next";
import Link from "next/link";

import {
  APP_NAME,
  LEGAL_LAST_UPDATED,
  PRIVACY_EMAIL,
  SUPPORT_EMAIL,
} from "@/lib/site";

export const metadata: Metadata = {
  title: `${APP_NAME} — Privacy Policy`,
  description: `How ${APP_NAME} collects, uses, stores and deletes your data.`,
};

export default function PrivacyPage() {
  return (
    <main className="site-container legal-page">
      <Link href="/" className="legal-back">
        ← Back to {APP_NAME}
      </Link>
      <h1>Privacy Policy</h1>
      <p className="site-muted">Last updated: {LEGAL_LAST_UPDATED}</p>

      <p>
        {APP_NAME} is a social AI-prompt library. This policy explains what we
        collect, why we collect it, where it is stored, who processes it, and how
        you can delete it. We do not sell your personal data and we do not show
        advertising.
      </p>

      <h2>1. Information we collect</h2>
      <ul>
        <li>
          <strong>Account data.</strong> Your email address, display name,
          username, bio, avatar URL, account role and status, and sign-in
          provider (email/password or Google). Passwords are handled by Supabase
          Auth and are never visible to us.
        </li>
        <li>
          <strong>Content you create.</strong> Prompts (title, description,
          prompt text, tags, model name), cover images, comments, likes,
          bookmarks, follows and reports. Cover images are stored in Appwrite
          Storage; the rest is stored in Supabase Postgres.
        </li>
        <li>
          <strong>Activity data.</strong> Like, copy, save, comment, follow and
          view counts; notification records; and a 24-hour deduplicated view
          identifier used to calculate trending prompts. Guest view identifiers
          are random and are not linked to your account.
        </li>
        <li>
          <strong>Device and push data.</strong> Firebase Cloud Messaging tokens,
          platform (Android/iOS), and token timestamps, so we can deliver the
          notifications you enable. You can disable notifications in Android
          settings at any time.
        </li>
        <li>
          <strong>Safety and operations data.</strong> Reports and moderation
          actions, including the admin who took an action and notes, plus
          server-side request logs (time, route, status, user ID where signed in).
        </li>
      </ul>

      <h2>2. How we use your information</h2>
      <ul>
        <li>To create and secure your account and sign you in.</li>
        <li>To show prompts, profiles, comments and counts to other users.</li>
        <li>To power search, categories, trending scores and your saved list.</li>
        <li>To send push notifications you have enabled (likes, comments, follows, remixes and moderation updates).</li>
        <li>To review reports, remove content and enforce our Terms.</li>
        <li>To debug failures, prevent abuse, and keep the service reliable.</li>
      </ul>

      <h2>3. What is public</h2>
      <p>
        Your <strong>email address is never public</strong>. Your name,
        username, bio, avatar and published prompts are public. Likes, bookmarks
        and following lists are visible only where the app&rsquo;s access rules
        allow them. Private and unlisted prompts are restricted to you (and
        administrators for moderation). Comments on a prompt are visible to
        anyone who can view that prompt.
      </p>

      <h2>4. Service providers</h2>
      <p>We use the following processors to run {APP_NAME}:</p>
      <ul>
        <li>
          <strong>Supabase</strong> — authentication, Postgres database, row-level
          security, realtime updates and legacy avatar/thumbnail storage.
        </li>
        <li>
          <strong>Appwrite</strong> — storage for new post cover images.
        </li>
        <li>
          <strong>Vercel</strong> — hosting for the website and the API that
          handles account deletion, moderation, media uploads and push delivery.
        </li>
        <li>
          <strong>Firebase Cloud Messaging (Google)</strong> — push notification
          delivery.
        </li>
        <li>
          <strong>Google Sign-In</strong> — optional Google account sign-in.
        </li>
        <li>
          <strong>GitHub</strong> — distribution of the Android APK and source
          code.
        </li>
      </ul>
      <p>
        These providers process data on our behalf under their own security and
        privacy terms. Some may process data outside your country; we rely on
        their standard contractual safeguards where required.
      </p>

      <h2>5. Retention and deletion</h2>
      <p>
        You can delete your account from <em>Settings → Delete account</em> in
        the app. The backend verifies your token, removes your avatar/thumbnail
        folders, deletes your auth user, and database foreign keys cascade to
        your profile, prompts, comments, likes, bookmarks, follows,
        notifications and push tokens. Deleted prompts trigger removal of their
        Appwrite cover images.
      </p>
      <p>
        Some records may remain for a limited period: security and request logs,
        moderation/audit records where needed to resolve abuse, and encrypted
        backups (typically up to 30 days). We do not retain deleted content for
        advertising or resale.
      </p>

      <h2>6. Security</h2>
      <p>
        Access is enforced with row-level security in Postgres and column-level
        grants. Privileged operations (account deletion, moderation, media
        uploads, push delivery) run on the server with service credentials that
        are never shipped in the app. No system is perfectly secure; please use a
        unique password and keep your device locked.
      </p>

      <h2>7. Children</h2>
      <p>
        {APP_NAME} is not directed at children under 13. We do not knowingly
        collect personal data from children under 13. If you believe a child has
        created an account, contact us and we will delete it.
      </p>

      <h2>8. Your choices and rights</h2>
      <p>
        You can edit your profile in the app, disable push notifications in your
        device settings, delete individual prompts/comments where the app offers
        it, or delete your whole account. Depending on your jurisdiction, you may
        also have the right to access, correct, export or restrict processing of
        your data. Email{" "}
        <a href={`mailto:${PRIVACY_EMAIL}`}>{PRIVACY_EMAIL}</a> and we will
        respond within a reasonable period.
      </p>

      <h2>9. Changes to this policy</h2>
      <p>
        We may update this policy as the product changes. The &ldquo;last
        updated&rdquo; date above will change, and material updates will be
        announced in the app. Continued use after an update means you accept the
        revised policy.
      </p>

      <h2>10. Contact</h2>
      <p>
        Privacy questions:{" "}
        <a href={`mailto:${PRIVACY_EMAIL}`}>{PRIVACY_EMAIL}</a>
        <br />
        General support:{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>
      </p>
    </main>
  );
}

import type { Metadata } from "next";
import Link from "next/link";

import {
  APP_NAME,
  LEGAL_LAST_UPDATED,
  SUPPORT_EMAIL,
} from "@/lib/site";

export const metadata: Metadata = {
  title: `${APP_NAME} — Terms of Service`,
  description: `The rules for using ${APP_NAME}.`,
};

export default function TermsPage() {
  return (
    <main className="site-container legal-page">
      <Link href="/" className="legal-back">
        ← Back to {APP_NAME}
      </Link>
      <h1>Terms of Service</h1>
      <p className="site-muted">Last updated: {LEGAL_LAST_UPDATED}</p>

      <p>
        These Terms govern your use of {APP_NAME} (the &ldquo;app&rdquo;) and
        the website at www.promptindo.app. By creating an account or using the
        app, you agree to these Terms and to our Privacy Policy. If you do not
        agree, do not use the app.
      </p>

      <h2>1. Eligibility and accounts</h2>
      <p>
        You must be at least 13 years old and legally able to agree to these
        Terms. Provide accurate account information, keep your password secure,
        and do not share your account. You are responsible for activity under
        your account. One person should not operate multiple accounts to evade
        moderation or inflate engagement.
      </p>

      <h2>2. Your content and licence</h2>
      <p>
        You retain ownership of the prompts, comments and images you create. By
        publishing content, you grant {APP_NAME} a non-exclusive, worldwide,
        royalty-free licence to host, store, display, distribute and promote that
        content inside the app and on prompt share pages. You confirm you have
        the rights needed to publish it and that it does not infringe anyone
        else&rsquo;s rights.
      </p>
      <p>
        You can delete your content or your account at any time. Deletion stops
        new distribution, but copies already saved by other users or cached by
        third-party services may persist outside our control.
      </p>

      <h2>3. Acceptable use</h2>
      <ul>
        <li>No spam, scams, malware, phishing or deceptive content.</li>
        <li>No harassment, threats, hate speech, or sexual content involving minors.</li>
        <li>No content that infringes copyright, trademarks, privacy or other rights.</li>
        <li>No scraping, bulk harvesting, reverse engineering or attempts to bypass rate limits or access controls.</li>
        <li>No using the app to break the law or to harm other people or systems.</li>
      </ul>

      <h2>4. AI-generated content</h2>
      <p>
        Prompts and their outputs may be inaccurate, incomplete or unsuitable for
        your situation. {APP_NAME} does not guarantee the results of any prompt
        or any third-party AI model. You are responsible for reviewing outputs
        before relying on them, especially for legal, medical, financial or
        safety-critical decisions.
      </p>

      <h2>5. Moderation and enforcement</h2>
      <p>
        Any user can report content. We may review, hide, remove or restrict
        content and accounts that violate these Terms or that we believe create
        risk for the community. Serious or repeated violations may result in a
        ban. You can appeal a moderation decision by emailing{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
      </p>

      <h2>6. Third-party services</h2>
      <p>
        The app uses Supabase, Appwrite, Vercel, Firebase Cloud Messaging and
        Google Sign-In. Your use of those services may also be subject to their
        terms. Links to third-party sites or models are provided for convenience;
        we do not control them.
      </p>

      <h2>7. Termination and account deletion</h2>
      <p>
        You may stop using the app at any time and delete your account from{" "}
        <em>Settings → Delete account</em>. We may suspend or terminate accounts
        that breach these Terms, create legal risk, or abuse the service. Where
        reasonable, we will explain the reason and offer an appeal channel.
      </p>

      <h2>8. Disclaimers</h2>
      <p>
        The app is provided &ldquo;as is&rdquo; and &ldquo;as available&rdquo;.
        To the maximum extent permitted by law, we disclaim warranties of
        merchantability, fitness for a particular purpose, and non-infringement.
        We do not warrant uninterrupted or error-free operation.
      </p>

      <h2>9. Limitation of liability</h2>
      <p>
        To the maximum extent permitted by law, {APP_NAME} and its operators are
        not liable for indirect, incidental, special, consequential or punitive
        damages, or for lost profits, data or goodwill, arising from your use of
        the app. Where liability cannot be excluded, it is limited to the amount
        you paid us in the 12 months before the claim (if any).
      </p>

      <h2>10. Changes to these Terms</h2>
      <p>
        We may update these Terms as the product evolves. The date above will
        change and material updates will be announced in the app. Continued use
        after an update means you accept the revised Terms.
      </p>

      <h2>11. Governing law</h2>
      <p>
        These Terms are governed by the laws of India, without regard to
        conflict-of-law rules. Courts in India have exclusive jurisdiction,
        subject to any mandatory consumer protections in your country.
      </p>

      <h2>12. Contact</h2>
      <p>
        Questions about these Terms:{" "}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>
      </p>
    </main>
  );
}

import type { Metadata, Viewport } from "next";
import "./globals.css";

import { getSiteUrl } from "@/lib/env";

export const metadata: Metadata = {
  metadataBase: new URL(getSiteUrl()),
  applicationName: "PromptIndo",
  title: "PromptIndo — Discover, share and remix AI prompts",
  description:
    "PromptIndo is a social AI-prompt library. Discover prompts that work, copy them in one tap, remix them, and share your own with images.",
  manifest: "/manifest.json",
  openGraph: {
    type: "website",
    siteName: "PromptIndo",
    title: "PromptIndo — Discover, share and remix AI prompts",
    description:
      "Discover prompts that work, copy them in one tap, remix them, and share your own with images.",
  },
  twitter: {
    card: "summary_large_image",
    title: "PromptIndo — Discover, share and remix AI prompts",
    description:
      "Discover prompts that work, copy them in one tap, remix them, and share your own with images.",
  },
};

export const viewport: Viewport = {
  themeColor: "#0a0a0a",
  colorScheme: "dark",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

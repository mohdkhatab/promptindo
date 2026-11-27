import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "PromptIndo",
  description:
    "A social platform for discovering, sharing and remixing AI prompts.",
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

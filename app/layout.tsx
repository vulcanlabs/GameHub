import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Game Hub",
  description: "LIVE interactive games for TikTok streamers",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}

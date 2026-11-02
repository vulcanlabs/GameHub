import type { Metadata } from "next";
import { Outfit } from "next/font/google";
import { HubAtmosphere } from "@/components/HubAtmosphere";
import "./globals.css";

const outfit = Outfit({
  subsets: ["latin"],
  display: "swap",
});

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
    <html lang="en" className={outfit.className}>
      <body className="antialiased">
        <HubAtmosphere />
        {children}
      </body>
    </html>
  );
}

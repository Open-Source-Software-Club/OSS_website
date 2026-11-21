import type { Metadata } from "next";
import "@/styles/globals.css";
import { SiteHeader } from "@/components/layout/SiteHeader";

export const metadata: Metadata = {
  title: "Open Source Software Club @ SVIT",
  description:
    "Official website for the Open Source Software Club at Sai Vidya Institute of Technology Bengaluru.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="min-h-screen max-w-[100vw] overflow-x-hidden bg-background font-sans antialiased">
        <SiteHeader />
        {children}
      </body>
    </html>
  );
}

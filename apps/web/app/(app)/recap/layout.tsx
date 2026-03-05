import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Recap",
  description: "View and share your weekly or monthly Claude Code usage recap card.",
};

export default function RecapLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

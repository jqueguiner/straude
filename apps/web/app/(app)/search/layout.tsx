import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Search",
  description: "Find and follow other Claude Code builders on Straude.",
};

export default function SearchLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}

import { redirect } from "next/navigation";
import { cookies } from "next/headers";
import Link from "next/link";
import { getServiceClient } from "@/lib/supabase/service";
import { Avatar } from "@/components/ui/Avatar";
import { Navbar } from "@/components/landing/Navbar";
import { Footer } from "@/components/landing/Footer";
import { Flame } from "lucide-react";
import type { Metadata } from "next";

export const revalidate = 300;

export async function generateMetadata({
  params,
}: {
  params: Promise<{ username: string }>;
}): Promise<Metadata> {
  const { username } = await params;
  const supabase = getServiceClient();

  const { data: referrer } = await supabase
    .from("users")
    .select("username, display_name, avatar_url, is_public")
    .eq("username", username)
    .single();

  if (!referrer || !referrer.is_public) {
    return { title: "Join Straude" };
  }

  // Fetch weekly spend for description
  const sevenDaysAgo = new Date(Date.now() - 7 * 86400000)
    .toISOString()
    .slice(0, 10);
  const { data: weeklyRows } = await supabase
    .from("daily_usage")
    .select("cost_usd")
    .eq("user_id", (await supabase.from("users").select("id").eq("username", username).single()).data?.id ?? "")
    .gte("date", sevenDaysAgo);

  const weeklySpend = weeklyRows?.reduce((s, r) => s + Number(r.cost_usd), 0) ?? 0;

  const description =
    weeklySpend > 0
      ? `@${username} spent $${weeklySpend.toFixed(2)} last week. Think you can keep up?`
      : `@${username} just joined Straude. Race them to the top.`;

  return {
    title: `Join @${username} on Straude`,
    description,
    openGraph: {
      title: `Join @${username} on Straude`,
      description,
      ...(referrer.avatar_url ? { images: [{ url: referrer.avatar_url }] } : {}),
    },
    twitter: {
      card: "summary",
      title: `Join @${username} on Straude`,
      description,
    },
  };
}

export default async function JoinPage({
  params,
}: {
  params: Promise<{ username: string }>;
}) {
  const { username } = await params;
  const supabase = getServiceClient();

  const { data: referrer } = await supabase
    .from("users")
    .select("id, username, display_name, avatar_url, is_public")
    .eq("username", username)
    .single();

  if (!referrer || !referrer.is_public) {
    redirect("/signup");
  }

  // Set ref cookie for attribution
  const cookieStore = await cookies();
  cookieStore.set("ref", username, {
    maxAge: 30 * 24 * 60 * 60, // 30 days
    path: "/",
    sameSite: "lax",
    httpOnly: false,
  });

  // Fetch stats in parallel
  const sevenDaysAgo = new Date(Date.now() - 7 * 86400000)
    .toISOString()
    .slice(0, 10);

  const [{ data: weeklyRows }, { data: totalRows }, streakResult] =
    await Promise.all([
      supabase
        .from("daily_usage")
        .select("cost_usd")
        .eq("user_id", referrer.id)
        .gte("date", sevenDaysAgo),
      supabase
        .from("daily_usage")
        .select("cost_usd")
        .eq("user_id", referrer.id),
      supabase.rpc("calculate_user_streak", {
        p_user_id: referrer.id,
        p_freeze_days: 0,
      }),
    ]);

  const weeklySpend =
    weeklyRows?.reduce((s, r) => s + Number(r.cost_usd), 0) ?? 0;
  const totalSpend =
    totalRows?.reduce((s, r) => s + Number(r.cost_usd), 0) ?? 0;
  const streak = (streakResult?.data as number) ?? 0;

  // Choose competitive headline
  let headline: string;
  let subline: string;

  if (weeklySpend > 0) {
    headline = `@${username} spent $${weeklySpend.toFixed(2)} on Claude Code last week.`;
    subline = "Think you can keep up?";
  } else if (totalSpend > 500) {
    headline = `@${username} has spent $${totalSpend.toFixed(0)} on AI coding.`;
    subline = "Where do you stand?";
  } else if (streak > 0) {
    headline = `@${username} has a ${streak}-day streak going.`;
    subline = "Start yours.";
  } else {
    headline = `@${username} just joined Straude.`;
    subline = "Race them to the top.";
  }

  return (
    <div className="flex min-h-screen flex-col bg-[#0a0a0a] text-[#ededed]">
      <Navbar />

      <main className="flex flex-1 flex-col items-center justify-center px-4 py-20">
        <div className="mx-auto max-w-lg text-center">
          <Avatar
            src={referrer.avatar_url}
            alt={referrer.username ?? ""}
            size="lg"
            fallback={referrer.username ?? "?"}
          />

          <h1
            className="mt-6 text-2xl font-semibold sm:text-3xl"
            style={{ letterSpacing: "-0.03em" }}
          >
            {headline}
          </h1>
          <p className="mt-2 text-xl text-[#999]">{subline}</p>

          {/* Stats row */}
          <div className="mt-8 flex justify-center gap-8">
            {streak > 0 && (
              <div>
                <p className="text-[0.7rem] uppercase tracking-widest text-[#666]">
                  Streak
                </p>
                <p className="inline-flex items-center gap-1 font-mono text-lg font-medium tabular-nums text-accent">
                  <Flame size={16} />
                  {streak}d
                </p>
              </div>
            )}
            <div>
              <p className="text-[0.7rem] uppercase tracking-widest text-[#666]">
                This Week
              </p>
              <p className="font-mono text-lg font-medium tabular-nums text-accent">
                ${weeklySpend.toFixed(2)}
              </p>
            </div>
            <div>
              <p className="text-[0.7rem] uppercase tracking-widest text-[#666]">
                All Time
              </p>
              <p className="font-mono text-lg font-medium tabular-nums text-accent">
                ${totalSpend.toFixed(2)}
              </p>
            </div>
          </div>

          {/* CTA */}
          <Link
            href="/signup"
            className="mt-10 inline-block rounded bg-accent px-8 py-3 text-sm font-semibold text-white transition-opacity hover:opacity-90"
          >
            Claim Your Profile
          </Link>
          <p className="mt-3 text-sm text-[#666]">
            One command. See where you rank.
          </p>
        </div>
      </main>

      <Footer />
    </div>
  );
}

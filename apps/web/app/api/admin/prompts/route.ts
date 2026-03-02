import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { getServiceClient } from "@/lib/supabase/service";
import { isAdmin } from "@/lib/admin";
import type { PromptSubmissionStatus } from "@/types";

const VALID_STATUSES: PromptSubmissionStatus[] = [
  "new",
  "accepted",
  "in_progress",
  "rejected",
  "shipped",
];

export async function GET(request: NextRequest) {
  const auth = await createClient();
  const {
    data: { user },
  } = await auth.auth.getUser();

  if (!user || !isAdmin(user.id)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const db = getServiceClient();
  const limit = Math.min(Math.max(Number(request.nextUrl.searchParams.get("limit")) || 50, 1), 200);
  const offset = Math.max(Number(request.nextUrl.searchParams.get("offset")) || 0, 0);
  const statusFilter = request.nextUrl.searchParams.get("status");

  let query = db
    .from("prompt_submissions")
    .select(
      "id,user_id,prompt,is_anonymous,status,is_public,is_hidden,admin_notes,pr_url,created_at,updated_at,reviewed_at,shipped_at,user:users!prompt_submissions_user_id_fkey(username,display_name)"
    )
    .order("created_at", { ascending: false })
    .range(offset, offset + limit - 1);

  if (statusFilter && statusFilter !== "all") {
    if (!VALID_STATUSES.includes(statusFilter as PromptSubmissionStatus)) {
      return NextResponse.json({ error: "Invalid status filter" }, { status: 400 });
    }
    query = query.eq("status", statusFilter);
  }

  const [rowsRes, countsRes] = await Promise.all([
    query,
    db.from("prompt_submissions").select("status,is_hidden"),
  ]);

  if (rowsRes.error || countsRes.error) {
    return NextResponse.json(
      { error: rowsRes.error?.message ?? countsRes.error?.message },
      { status: 500 },
    );
  }

  const counts = {
    all: 0,
    new: 0,
    accepted: 0,
    in_progress: 0,
    rejected: 0,
    shipped: 0,
    hidden: 0,
  };

  for (const row of countsRes.data ?? []) {
    counts.all += 1;
    if (row.is_hidden) counts.hidden += 1;
    const status = row.status as PromptSubmissionStatus;
    if (status in counts) {
      counts[status] += 1;
    }
  }

  return NextResponse.json({
    prompts: rowsRes.data ?? [],
    counts,
  });
}

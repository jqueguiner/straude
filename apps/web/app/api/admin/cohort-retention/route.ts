import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { getServiceClient } from "@/lib/supabase/service";
import { isAdmin } from "@/lib/admin";

export async function GET() {
  const auth = await createClient();
  const {
    data: { user },
  } = await auth.auth.getUser();

  if (!user || !isAdmin(user.id)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const db = getServiceClient();
  const { data, error } = await db.rpc("admin_cohort_retention");

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  const rows = (data ?? []).map((r: any) => ({
    cohort_week: r.cohort_week,
    cohort_size: Number(r.cohort_size),
    week_0: r.week_0 !== null ? Number(r.week_0) : null,
    week_1: r.week_1 !== null ? Number(r.week_1) : null,
    week_2: r.week_2 !== null ? Number(r.week_2) : null,
    week_3: r.week_3 !== null ? Number(r.week_3) : null,
    week_4: r.week_4 !== null ? Number(r.week_4) : null,
  }));

  return NextResponse.json(rows);
}

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

function normalizeOptionalText(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, maxLength) : null;
}

export async function PATCH(
  request: NextRequest,
  context: { params: Promise<{ id: string }> },
) {
  const auth = await createClient();
  const {
    data: { user },
  } = await auth.auth.getUser();

  if (!user || !isAdmin(user.id)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await context.params;
  let body: {
    status?: unknown;
    is_hidden?: unknown;
    admin_notes?: unknown;
    pr_url?: unknown;
  };

  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const updates: Record<string, unknown> = {
    reviewed_by: user.id,
    reviewed_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  let changed = false;

  if (body.status !== undefined) {
    if (typeof body.status !== "string" || !VALID_STATUSES.includes(body.status as PromptSubmissionStatus)) {
      return NextResponse.json({ error: "Invalid status" }, { status: 400 });
    }
    updates.status = body.status;
    updates.shipped_at = body.status === "shipped" ? new Date().toISOString() : null;
    changed = true;
  }

  if (body.is_hidden !== undefined) {
    if (typeof body.is_hidden !== "boolean") {
      return NextResponse.json({ error: "is_hidden must be a boolean" }, { status: 400 });
    }
    updates.is_hidden = body.is_hidden;
    changed = true;
  }

  if (body.admin_notes !== undefined) {
    updates.admin_notes = normalizeOptionalText(body.admin_notes, 2000);
    changed = true;
  }

  if (body.pr_url !== undefined) {
    updates.pr_url = normalizeOptionalText(body.pr_url, 500);
    changed = true;
  }

  if (!changed) {
    return NextResponse.json(
      { error: "Provide at least one editable field" },
      { status: 400 },
    );
  }

  const db = getServiceClient();
  const { data, error } = await db
    .from("prompt_submissions")
    .update(updates)
    .eq("id", id)
    .select(
      "id,user_id,prompt,is_anonymous,status,is_public,is_hidden,admin_notes,pr_url,created_at,updated_at,reviewed_at,shipped_at,user:users!prompt_submissions_user_id_fkey(username,display_name)"
    )
    .single();

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({ prompt: data });
}

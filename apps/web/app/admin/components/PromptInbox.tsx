"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { timeAgo } from "@/lib/utils/format";
import type { PromptSubmissionStatus } from "@/types";

type AdminPromptRow = {
  id: string;
  prompt: string;
  is_anonymous: boolean;
  status: PromptSubmissionStatus;
  is_hidden: boolean;
  created_at: string;
  user?: {
    username?: string | null;
    display_name?: string | null;
  } | null;
};

const FILTERS: Array<{ value: "all" | PromptSubmissionStatus; label: string }> = [
  { value: "new", label: "New" },
  { value: "all", label: "All" },
  { value: "accepted", label: "Accepted" },
  { value: "in_progress", label: "In Progress" },
  { value: "rejected", label: "Rejected" },
  { value: "shipped", label: "Shipped" },
];

const STATUS_OPTIONS: PromptSubmissionStatus[] = [
  "new",
  "accepted",
  "in_progress",
  "rejected",
  "shipped",
];

function statusLabel(status: PromptSubmissionStatus): string {
  if (status === "in_progress") return "In progress";
  return status[0]!.toUpperCase() + status.slice(1);
}

export function PromptInbox({ initialPrompts }: { initialPrompts: AdminPromptRow[] }) {
  const [prompts, setPrompts] = useState(initialPrompts);
  const [filter, setFilter] = useState<"all" | PromptSubmissionStatus>("new");
  const [savingId, setSavingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const counts = useMemo(() => {
    const next = {
      all: prompts.length,
      new: 0,
      accepted: 0,
      in_progress: 0,
      rejected: 0,
      shipped: 0,
    };
    for (const prompt of prompts) {
      next[prompt.status] += 1;
    }
    return next;
  }, [prompts]);

  const filtered = useMemo(() => {
    if (filter === "all") return prompts;
    return prompts.filter((p) => p.status === filter);
  }, [filter, prompts]);

  async function patchPrompt(id: string, payload: Record<string, unknown>) {
    setSavingId(id);
    setError(null);
    try {
      const res = await fetch(`/api/admin/prompts/${id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const body = await res.json().catch(() => ({}));
      if (!res.ok) {
        setError(body.error ?? "Update failed");
        return;
      }
      const updated = body.prompt as AdminPromptRow;
      setPrompts((prev) => prev.map((p) => (p.id === id ? { ...p, ...updated } : p)));
    } finally {
      setSavingId(null);
    }
  }

  return (
    <section className="admin-card p-4 sm:p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="text-base font-semibold">Prompt Inbox</h3>
          <p className="text-sm" style={{ color: "var(--admin-fg-secondary)" }}>
            Review user-submitted prompts for features and fixes.
          </p>
        </div>
      </div>

      <div className="mb-4 flex flex-wrap gap-2">
        {FILTERS.map((item) => (
          <button
            key={item.value}
            type="button"
            onClick={() => setFilter(item.value)}
            className="rounded-[4px] border px-2.5 py-1.5 text-xs font-medium"
            style={{
              borderColor: "var(--admin-border)",
              background: filter === item.value ? "var(--admin-pill-active-bg)" : "var(--admin-pill-bg)",
              color: filter === item.value ? "var(--admin-pill-active-fg)" : "var(--admin-fg-secondary)",
            }}
          >
            {item.label}
            <span className="ml-1 tabular-nums opacity-75">
              ({item.value === "all" ? counts.all : counts[item.value]})
            </span>
          </button>
        ))}
      </div>

      {error && (
        <p className="mb-3 text-sm" style={{ color: "#C94A4A" }} role="alert">
          {error}
        </p>
      )}

      {filtered.length === 0 ? (
        <p className="text-sm" style={{ color: "var(--admin-fg-secondary)" }}>
          No prompts in this filter.
        </p>
      ) : (
        <div className="divide-y" style={{ borderColor: "var(--admin-border)" }}>
          {filtered.map((row) => {
            const username = row.user?.username ?? null;
            const isSaving = savingId === row.id;
            return (
              <article key={row.id} className="py-4 first:pt-0 last:pb-0">
                <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-2 text-sm">
                    {username ? (
                      <Link href={`/u/${username}`} className="font-semibold" style={{ color: "var(--admin-accent)" }}>
                        @{username}
                      </Link>
                    ) : (
                      <span className="font-semibold" style={{ color: "var(--admin-fg-secondary)" }}>
                        Unknown user
                      </span>
                    )}
                    <span suppressHydrationWarning style={{ color: "var(--admin-fg-secondary)" }}>
                      {timeAgo(row.created_at)}
                    </span>
                    {row.is_hidden && (
                      <span
                        className="rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide"
                        style={{
                          background: "var(--admin-pill-bg)",
                          color: "var(--admin-fg-secondary)",
                        }}
                      >
                        Hidden
                      </span>
                    )}
                    {row.is_anonymous && (
                      <span
                        className="rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide"
                        style={{
                          background: "var(--admin-pill-bg)",
                          color: "var(--admin-fg-secondary)",
                        }}
                      >
                        Anonymous in community
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-2">
                    <select
                      value={row.status}
                      onChange={(e) => {
                        void patchPrompt(row.id, { status: e.target.value });
                      }}
                      disabled={isSaving}
                      className="rounded-[4px] border px-2 py-1 text-xs"
                      style={{
                        borderColor: "var(--admin-border)",
                        background: "var(--admin-card)",
                        color: "var(--admin-fg)",
                      }}
                      aria-label={`Status for prompt ${row.id}`}
                    >
                      {STATUS_OPTIONS.map((status) => (
                        <option key={status} value={status}>
                          {statusLabel(status)}
                        </option>
                      ))}
                    </select>

                    <button
                      type="button"
                      disabled={isSaving}
                      onClick={() => {
                        void patchPrompt(row.id, { is_hidden: !row.is_hidden });
                      }}
                      className="rounded-[4px] border px-2 py-1 text-xs"
                      style={{
                        borderColor: "var(--admin-border)",
                        color: "var(--admin-fg-secondary)",
                      }}
                    >
                      {row.is_hidden ? "Unhide" : "Hide"}
                    </button>
                  </div>
                </div>

                <p className="whitespace-pre-wrap text-sm leading-relaxed">{row.prompt}</p>
              </article>
            );
          })}
        </div>
      )}
    </section>
  );
}

"use client";

import { useEffect, useState } from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
} from "recharts";
import { useAdminTheme } from "./AdminShell";

interface Bucket {
  bucket: string;
  bucket_order: number;
  user_count: number;
}

function Skeleton() {
  return (
    <div className="admin-card">
      <div className="px-5 pt-4 pb-2">
        <h2
          className="text-sm font-semibold"
          style={{ color: "var(--admin-fg)" }}
        >
          Time to First Sync
        </h2>
        <p
          className="mt-0.5 text-xs"
          style={{ color: "var(--admin-fg-muted)" }}
        >
          How fast users push their first data
        </p>
      </div>
      <div className="h-[240px] px-5 pb-4 flex items-end gap-2">
        {[0.4, 0.7, 1, 0.6, 0.3, 0.2].map((h, i) => (
          <div
            key={i}
            className="flex-1 animate-pulse rounded-t"
            style={{
              height: `${h * 100}%`,
              backgroundColor: "var(--admin-border)",
            }}
          />
        ))}
      </div>
    </div>
  );
}

export function TimeToFirstSync() {
  const { theme } = useAdminTheme();
  const isDark = theme === "dark";
  const [data, setData] = useState<Bucket[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch("/api/admin/time-to-first-sync")
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then(setData)
      .catch((err) => setError(err.message));
  }, []);

  if (error) {
    return (
      <div className="admin-card">
        <div className="px-5 py-4">
          <p className="text-sm" style={{ color: "var(--admin-fg-muted)" }}>
            Failed to load time to first sync
          </p>
        </div>
      </div>
    );
  }

  if (!data) return <Skeleton />;

  const gridColor = isDark ? "rgba(255,255,255,0.04)" : "rgba(0,0,0,0.06)";
  const axisColor = isDark ? "#555" : "#999";
  const tooltipBg = isDark ? "#1A1A1A" : "#FFF";
  const tooltipBorder = isDark
    ? "rgba(255,255,255,0.08)"
    : "rgba(0,0,0,0.12)";

  const total = data.reduce((sum, d) => sum + d.user_count, 0);

  return (
    <div className="admin-card">
      <div className="px-5 pt-4 pb-2">
        <h2
          className="text-sm font-semibold"
          style={{ color: "var(--admin-fg)" }}
        >
          Time to First Sync
        </h2>
        <p
          className="mt-0.5 text-xs"
          style={{ color: "var(--admin-fg-muted)" }}
        >
          How fast users push their first data
        </p>
      </div>
      <div className="h-[240px] px-2 pb-4">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data} barCategoryGap="20%">
            <CartesianGrid
              strokeDasharray="3 3"
              stroke={gridColor}
              vertical={false}
            />
            <XAxis
              dataKey="bucket"
              tick={{ fontSize: 11, fill: axisColor }}
              tickLine={false}
              axisLine={false}
            />
            <YAxis
              tick={{ fontSize: 11, fill: axisColor }}
              tickLine={false}
              axisLine={false}
              width={30}
            />
            <Tooltip
              formatter={(value) => {
                const pct =
                  total > 0
                    ? Math.round((Number(value) / total) * 100)
                    : 0;
                return [`${value} users (${pct}%)`, "Count"];
              }}
              contentStyle={{
                fontSize: 12,
                fontFamily: "var(--font-mono)",
                background: tooltipBg,
                border: `1px solid ${tooltipBorder}`,
                borderRadius: 8,
                boxShadow: "none",
              }}
            />
            <Bar dataKey="user_count" radius={[4, 4, 0, 0]}>
              {data.map((entry) => (
                <Cell
                  key={entry.bucket}
                  fill="#DF561F"
                  fillOpacity={entry.bucket === "Never" ? 0.25 : 0.7}
                />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

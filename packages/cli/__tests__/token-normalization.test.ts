import { describe, it, expect } from "vitest";
import { normalizeTokenBuckets } from "../src/lib/token-normalization.js";

describe("normalizeTokenBuckets", () => {
  it("normalizes codex inclusive-cache input to non-cached input", () => {
    const result = normalizeTokenBuckets(
      {
        inputTokens: 3_305_677,
        cachedInputTokens: 3_161_216,
        outputTokens: 27_407,
        reasoningOutputTokens: 15_913,
        totalTokens: 3_333_084,
      },
      { source: "codex", cacheSemantics: "auto" },
    );

    expect(result.normalized.inputTokens).toBe(144_461);
    expect(result.normalized.cacheReadTokens).toBe(3_161_216);
    expect(result.normalized.outputTokens).toBe(27_407);
    expect(result.meta.mode).toBe("inclusive_cache_input");
    expect(result.meta.confidence).toBe("high");
  });

  it("passes through already-normalized separate cache fields", () => {
    const result = normalizeTokenBuckets(
      {
        inputTokens: 144_461,
        cacheReadTokens: 3_161_216,
        outputTokens: 27_407,
        totalTokens: 3_333_084,
      },
      { source: "codex", cacheSemantics: "auto" },
    );

    expect(result.normalized.inputTokens).toBe(144_461);
    expect(result.normalized.cacheReadTokens).toBe(3_161_216);
    expect(result.meta.mode).toBe("pass_through_normalized");
    expect(result.meta.confidence).toBe("high");
  });

  it("clamps cache read to input when cache exceeds input in inclusive mode", () => {
    const result = normalizeTokenBuckets(
      {
        inputTokens: 100,
        cachedInputTokens: 200,
        outputTokens: 10,
        totalTokens: 110,
      },
      { source: "codex", cacheSemantics: "auto" },
    );

    expect(result.normalized.inputTokens).toBe(0);
    expect(result.normalized.cacheReadTokens).toBe(100);
    expect(result.meta.mode).toBe("inclusive_cache_input");
  });

  it("clamps reasoning to an output subset for diagnostics", () => {
    const result = normalizeTokenBuckets(
      {
        inputTokens: 100,
        outputTokens: 20,
        reasoningOutputTokens: 50,
        totalTokens: 120,
      },
      { source: "generic", cacheSemantics: "auto" },
    );

    expect(result.normalized.outputTokens).toBe(20);
    expect(result.normalized.reasoningOutputTokens).toBe(20);
    expect(result.meta.warnings).toContain(
      "reasoningOutputTokens exceeded outputTokens; clamped informational reasoning value.",
    );
  });

  it("applies deterministic output adjustment when residual matches reasoning tokens", () => {
    const result = normalizeTokenBuckets(
      {
        inputTokens: 100,
        outputTokens: 50,
        cacheReadTokens: 20,
        reasoningOutputTokens: 10,
        totalTokens: 180,
      },
      { source: "generic", cacheSemantics: "separate" },
    );

    expect(result.normalized.outputTokens).toBe(60);
    expect(result.meta.mode).toBe("inferred_output_adjustment");
    expect(result.meta.confidence).toBe("high");
    expect(result.meta.warnings).toContain(
      "Adjusted outputTokens by reasoningOutputTokens to satisfy source total.",
    );
  });

  it("keeps output unchanged for non-deterministic residual and emits warning", () => {
    const result = normalizeTokenBuckets(
      {
        inputTokens: 100,
        outputTokens: 50,
        cacheReadTokens: 20,
        reasoningOutputTokens: 10,
        totalTokens: 190,
      },
      { source: "generic", cacheSemantics: "separate" },
    );

    expect(result.normalized.outputTokens).toBe(50);
    expect(result.meta.mode).toBe("pass_through_normalized");
    expect(result.meta.confidence).toBe("low");
    expect(result.meta.warnings.some((w) => w.includes("Token consistency residual"))).toBe(true);
  });
});

import { beforeEach, describe, expect, it, vi } from "vitest";
import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { CommentThread } from "@/components/app/post/CommentThread";

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((res) => {
    resolve = res;
  });
  return { promise, resolve };
}

function mockCreatedComment(username: string) {
  return {
    id: "comment-1",
    post_id: "post-1",
    user_id: "user-1",
    content: "Shipped a fix for this.",
    created_at: "2026-03-01T12:00:00.000Z",
    updated_at: "2026-03-01T12:00:00.000Z",
    user: { username, avatar_url: null },
  };
}

describe("CommentThread", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("shows the logged-in username immediately for optimistic comments", async () => {
    const pending = deferred<any>();
    vi.spyOn(global, "fetch" as any).mockReturnValue(pending.promise);

    render(
      <CommentThread
        postId="post-1"
        initialComments={[]}
        userId="user-1"
        currentUser={{ username: "alice", avatar_url: null }}
      />,
    );

    fireEvent.change(screen.getByPlaceholderText(/add a comment/i), {
      target: { value: "Shipped a fix for this." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Post" }));
    expect(screen.getByRole("button", { name: "..." })).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByText("alice")).toBeInTheDocument();
      expect(screen.queryByText("anonymous")).not.toBeInTheDocument();
    });

    await act(async () => {
      pending.resolve({
        ok: true,
        json: async () => mockCreatedComment("alice"),
      });
      await Promise.resolve();
    });

    await waitFor(() => {
      expect(screen.getByRole("button", { name: "Post" })).toBeInTheDocument();
    });
  });

  it("never shows anonymous for optimistic self-comments when profile data is missing", async () => {
    const pending = deferred<any>();
    vi.spyOn(global, "fetch" as any).mockReturnValue(pending.promise);

    render(
      <CommentThread
        postId="post-1"
        initialComments={[]}
        userId="user-1"
      />,
    );

    fireEvent.change(screen.getByPlaceholderText(/add a comment/i), {
      target: { value: "Shipped a fix for this." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Post" }));
    expect(screen.getByRole("button", { name: "..." })).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByText("you")).toBeInTheDocument();
      expect(screen.queryByText("anonymous")).not.toBeInTheDocument();
    });

    await act(async () => {
      pending.resolve({
        ok: true,
        json: async () => mockCreatedComment("alice"),
      });
      await Promise.resolve();
    });

    await waitFor(() => {
      expect(screen.getByText("alice")).toBeInTheDocument();
    });
  });
});

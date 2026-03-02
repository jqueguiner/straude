create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  actor_id uuid not null references public.users(id) on delete cascade,
  type text not null check (type in ('follow', 'kudos', 'comment')),
  post_id uuid references public.posts(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index idx_notifications_user_id on public.notifications(user_id, created_at desc);
create index idx_notifications_unread on public.notifications(user_id) where read = false;

alter table public.notifications enable row level security;

create policy "Users can read own notifications"
  on public.notifications for select using (auth.uid() = user_id);
create policy "Users can update own notifications"
  on public.notifications for update using (auth.uid() = user_id);;

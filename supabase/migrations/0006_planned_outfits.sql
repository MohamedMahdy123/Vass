-- ---------------------------------------------------------------------------
-- 0006_planned_outfits — the outfit calendar: which saved look is planned for
-- a given day. One look per day per user (upsert on conflict). Deleting an
-- outfit clears its plans (cascade). Demo mode plans in memory; this table
-- backs the signed-in experience.
-- ---------------------------------------------------------------------------

create table if not exists public.planned_outfits (
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  plan_date  date not null,
  outfit_id  uuid not null references public.outfits (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, plan_date)
);

create index if not exists planned_outfits_user_idx
  on public.planned_outfits (user_id, plan_date);

alter table public.planned_outfits enable row level security;

create policy "own planned outfits: all"
  on public.planned_outfits for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

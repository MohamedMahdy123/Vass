-- Vess — initial schema (M0)
-- Postgres + Row Level Security. Every table is scoped to the owning user;
-- a user can only ever see or touch their own rows. The Edge Functions and the
-- app both talk to these tables through the user's JWT, so RLS is the real
-- security boundary — not app code.

-- ---------------------------------------------------------------------------
-- profiles — 1:1 with auth.users, created automatically on sign-up
-- ---------------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  email         text,
  display_name  text,
  style_tags    text[] not null default '{}',
  plan_tier     text   not null default 'free' check (plan_tier in ('free', 'pro')),
  created_at    timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "own profile: read"
  on public.profiles for select using (auth.uid() = id);
create policy "own profile: update"
  on public.profiles for update using (auth.uid() = id);

-- Auto-provision a profile row whenever a new auth user is created.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, split_part(coalesce(new.email, ''), '@', 1));
  insert into public.preferences (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- items — one garment. Attributes are stored as text so the recommender
-- reasons over text, never re-analyzing the photo.
-- ---------------------------------------------------------------------------
create table public.items (
  id            uuid primary key default gen_random_uuid(),
  -- default auth.uid(): PostgREST sets the owner from the caller's JWT on
  -- insert, so the client never sends user_id. RLS then checks it matches.
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  image_path    text,                         -- path in the 'wardrobe' storage bucket
  name          text not null default 'Untitled',
  category      text,
  color         text,
  material      text,
  pattern       text,
  season        text,
  occasion      text,
  brand         text,
  favorite      boolean not null default false,
  wear_count    integer not null default 0,
  last_worn_at  timestamptz,
  -- 'pending'  = awaiting AI tagging, 'tagged' = AI done (unreviewed),
  -- 'reviewed' = user confirmed. Drives the batch-capture review queue.
  status        text not null default 'pending'
                  check (status in ('pending', 'tagged', 'reviewed')),
  created_at    timestamptz not null default now()
);

create index items_user_idx on public.items (user_id, created_at desc);
create index items_user_category_idx on public.items (user_id, category);

alter table public.items enable row level security;

create policy "own items: all"
  on public.items for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- outfits — a suggested/accepted/rejected look, with the AI's reason
-- ---------------------------------------------------------------------------
create table public.outfits (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title       text,
  occasion    text,
  reason      text,                             -- the "why" shown to the user
  status      text not null default 'suggested'
                check (status in ('suggested', 'accepted', 'rejected')),
  for_date    date not null default current_date,
  created_at  timestamptz not null default now()
);

create index outfits_user_idx on public.outfits (user_id, for_date desc);

alter table public.outfits enable row level security;

create policy "own outfits: all"
  on public.outfits for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- outfit_items — which garments make up an outfit
create table public.outfit_items (
  outfit_id  uuid not null references public.outfits (id) on delete cascade,
  item_id    uuid not null references public.items (id) on delete cascade,
  slot       text,                              -- 'Top' | 'Bottom' | 'Outerwear' | 'Shoes' | ...
  primary key (outfit_id, item_id)
);

alter table public.outfit_items enable row level security;

-- Access is derived from the parent outfit's ownership.
create policy "own outfit_items: all"
  on public.outfit_items for all
  using (exists (
    select 1 from public.outfits o
    where o.id = outfit_id and o.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.outfits o
    where o.id = outfit_id and o.user_id = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- preferences — the honest heuristic behind "gets to know your style".
-- Not trained ML: liked pairings, disliked items, explicit style tags.
-- ---------------------------------------------------------------------------
create table public.preferences (
  user_id           uuid primary key references auth.users (id) on delete cascade,
  liked_pairings    jsonb  not null default '[]',   -- [[item_id, item_id], ...]
  disliked_item_ids uuid[] not null default '{}',
  style_tags        text[] not null default '{}',
  updated_at        timestamptz not null default now()
);

alter table public.preferences enable row level security;

create policy "own preferences: all"
  on public.preferences for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- usage_events — append-only log for enforcing free-tier quotas (M4).
-- kind: 'analyze' (photo tagged) | 'recommend' (outfit generated)
-- ---------------------------------------------------------------------------
create table public.usage_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  kind        text not null check (kind in ('analyze', 'recommend')),
  created_at  timestamptz not null default now()
);

create index usage_user_kind_time_idx
  on public.usage_events (user_id, kind, created_at desc);

alter table public.usage_events enable row level security;

create policy "own usage: read"
  on public.usage_events for select using (auth.uid() = user_id);
-- Inserts are performed by Edge Functions using the service role, which
-- bypasses RLS — clients never write usage rows directly.

-- ---------------------------------------------------------------------------
-- storage — private 'wardrobe' bucket, one folder per user
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('wardrobe', 'wardrobe', false)
on conflict (id) do nothing;

-- Files live at wardrobe/<user_id>/<item>.jpg; a user only reaches their folder.
create policy "wardrobe: own folder read"
  on storage.objects for select
  using (bucket_id = 'wardrobe' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "wardrobe: own folder write"
  on storage.objects for insert
  with check (bucket_id = 'wardrobe' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "wardrobe: own folder delete"
  on storage.objects for delete
  using (bucket_id = 'wardrobe' and (storage.foldername(name))[1] = auth.uid()::text);

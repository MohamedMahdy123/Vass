-- Vess — Complete-the-Look (go-live)
-- Logs missing-item suggestions and the affiliate funnel (impression → click →
-- conversion) for analytics. Owner-only RLS, same boundary as items/outfits.
-- Offers themselves are fetched live from a provider and not stored.

create table public.missing_item_suggestions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  outfit_id   uuid references public.outfits (id) on delete set null,
  slot        text,                 -- 'Belt' | 'Bag' | 'Outerwear'
  descriptor  jsonb,                -- {category, color, material, style}
  reason      text,
  source      text check (source in ('closet', 'shop')),
  created_at  timestamptz not null default now()
);

create index missing_item_user_idx on public.missing_item_suggestions (user_id, created_at desc);

alter table public.missing_item_suggestions enable row level security;

create policy "own suggestions: all"
  on public.missing_item_suggestions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table public.affiliate_events (
  id            bigint generated always as identity primary key,
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  suggestion_id uuid references public.missing_item_suggestions (id) on delete set null,
  provider      text,               -- 'shopstyle' | 'skimlinks' | 'mock'
  product_url   text,
  brand         text,
  event         text not null check (event in ('impression', 'click', 'conversion')),
  value_cents   integer,            -- commission on conversion, when reported
  created_at    timestamptz not null default now()
);

create index affiliate_user_event_idx on public.affiliate_events (user_id, event, created_at desc);

alter table public.affiliate_events enable row level security;

create policy "own affiliate events: all"
  on public.affiliate_events for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

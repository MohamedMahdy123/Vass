-- Vess — Virtual Try-On (T1)
-- Adds the try-on feature alongside the wardrobe: a user tries a garment (from
-- their closet, an upload, or the platform catalog) on a photo of themselves,
-- and an image model renders the result. Full-body photos are sensitive PII, so
-- everything here is private + RLS-scoped, and the generative call happens only
-- server-side (Edge Function) — the app never holds the provider key.

-- ---------------------------------------------------------------------------
-- catalog_items — platform-provided garments a user can try on.
-- Readable by any signed-in user; only the service role (admin tooling) writes.
-- ---------------------------------------------------------------------------
create table public.catalog_items (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  brand       text,
  category    text,
  color       text,
  image_path  text not null,               -- path in the public 'catalog' bucket
  price_cents integer,
  currency    text not null default 'USD',
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create index catalog_active_idx on public.catalog_items (active, category);

alter table public.catalog_items enable row level security;

-- Everyone signed in can browse the catalog; no client write policy exists, so
-- inserts/updates are possible only via the service role.
create policy "catalog: read for authenticated"
  on public.catalog_items for select
  to authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- tryons — one try-on request and its result.
-- garment_source says where the garment came from; exactly one of the three
-- garment references is populated to match it.
-- ---------------------------------------------------------------------------
create table public.tryons (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null default auth.uid() references auth.users (id) on delete cascade,
  person_image_path  text not null,        -- <uid>/... in the private 'tryon' bucket
  garment_source     text not null check (garment_source in ('closet', 'upload', 'catalog')),
  garment_item_id    uuid references public.items (id) on delete set null,
  garment_catalog_id uuid references public.catalog_items (id) on delete set null,
  garment_image_path text,                  -- for 'upload': <uid>/garments/... in 'tryon'
  result_image_path  text,                  -- populated on success
  status             text not null default 'pending'
                       check (status in ('pending', 'processing', 'succeeded', 'failed')),
  model              text,                   -- e.g. 'fashn/tryon/v1.6'
  error              text,
  created_at         timestamptz not null default now()
);

create index tryons_user_idx on public.tryons (user_id, created_at desc);

alter table public.tryons enable row level security;

create policy "own tryons: all"
  on public.tryons for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- usage_events — extend the quota log with the try-on kind (compute-heavy →
-- paywalled/quota-gated in M4).
-- ---------------------------------------------------------------------------
alter table public.usage_events
  drop constraint if exists usage_events_kind_check;
alter table public.usage_events
  add constraint usage_events_kind_check
  check (kind in ('analyze', 'recommend', 'tryon'));

-- ---------------------------------------------------------------------------
-- storage — 'tryon' (private: body photos, uploaded garments, results),
-- one folder per user; and 'catalog' (public: product images).
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('tryon', 'tryon', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('catalog', 'catalog', true)
on conflict (id) do nothing;

-- Files live at tryon/<user_id>/...; a user only ever reaches their own folder.
create policy "tryon: own folder read"
  on storage.objects for select
  using (bucket_id = 'tryon' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "tryon: own folder write"
  on storage.objects for insert
  with check (bucket_id = 'tryon' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "tryon: own folder delete"
  on storage.objects for delete
  using (bucket_id = 'tryon' and (storage.foldername(name))[1] = auth.uid()::text);

-- Catalog images are public-read (product photos); only the service role writes.
create policy "catalog: public read"
  on storage.objects for select
  using (bucket_id = 'catalog');

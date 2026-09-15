-- Vess — enrich the wardrobe item (ClothingItem) for the AI stylist, weather
-- matching and outfit assembly. Additive + backfilled: existing rows and the
-- legacy single-value columns (color, occasion, season, material) are kept and
-- still populated by the client, so nothing downstream breaks.
--
-- Every item remains User-Generated Content — a user's own uploaded photo,
-- background-removed and AI-tagged, scoped by the existing RLS on public.items.

alter table public.items
  add column if not exists processed_image_url text,        -- transparent-BG version
  add column if not exists sub_category        text,        -- e.g. 'Oxford shirt', 'Chelsea boot'
  add column if not exists occasions           text[] not null default '{}',  -- Casual, Work, Formal, Party…
  add column if not exists seasons             text[] not null default '{}',  -- Spring, Summer, Autumn, Winter, All
  add column if not exists weather_tags        text[] not null default '{}',  -- Hot, Warm, Cold, Rain, temp range
  add column if not exists color_primary       text,
  add column if not exists color_secondary     text,
  add column if not exists fabric_type         text;

-- Backfill the rich columns from the legacy single-value columns.
update public.items set
  color_primary = coalesce(color_primary, color),
  fabric_type   = coalesce(fabric_type, material),
  occasions = case
                when array_length(occasions, 1) is not null then occasions
                when occasion is not null and occasion <> '' then array[occasion]
                else '{}'
              end,
  seasons   = case
                when array_length(seasons, 1) is not null then seasons
                when season is not null and season <> '' then array[season]
                else '{}'
              end,
  weather_tags = case
                   when array_length(weather_tags, 1) is not null then weather_tags
                   when lower(coalesce(season,'')) = 'winter' then array['Cold']
                   when lower(coalesce(season,'')) = 'summer' then array['Hot','Warm']
                   when lower(coalesce(season,'')) in ('spring','autumn','fall') then array['Mild']
                   else '{}'
                 end;

-- Helpful indexes for occasion / weather filtering.
create index if not exists items_occasions_gin  on public.items using gin (occasions);
create index if not exists items_weather_gin     on public.items using gin (weather_tags);

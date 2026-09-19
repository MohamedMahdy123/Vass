-- ---------------------------------------------------------------------------
-- 0005_saved_outfits — persist canvas "My Outfits" alongside recommendations.
--
-- The outfits table already stores recommendation looks (suggested/accepted/
-- rejected). Canvas-composed looks the user saves from the Outfit Canvas are a
-- different kind of row: keep them in the same table but tag them so "My
-- Outfits" can list only user-saved looks without pulling in recommendation
-- history. Adding a nullable column with a default is backward-compatible —
-- existing rows become 'recommendation' automatically.
-- ---------------------------------------------------------------------------

alter table public.outfits
  add column if not exists source text not null default 'recommendation'
    check (source in ('recommendation', 'canvas'));

-- Fast lookup for the My Outfits gallery (own canvas looks, newest first).
create index if not exists outfits_source_idx
  on public.outfits (user_id, source, created_at desc);

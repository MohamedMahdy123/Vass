# Garment cut-out assets

Transparent-background product shots for the **demo wardrobe**. Each file is the
`processed_image_url` (background-removed cut-out) for one seed piece defined in
`lib/state/wardrobe_state.dart` → `_demoSeed()`.

## Format

- **Transparent PNG** (RGBA), roughly **square** (~512×512 or larger).
- The garment **centred** with a little breathing room — `ItemImage` mats it
  `BoxFit.contain` with ~10% padding on the neutral catalog card, so the piece
  must not run to the edges.
- No baked-in background: the card ground behind it is drawn by the app.

## Files

`demo-1.png … demo-12.png`, keyed by the seed item `id`. To restyle a demo
piece, replace its file in place — no code change needed.

## Regenerating the placeholders

The bundled images are illustrated placeholders rendered by
`tool/render_garments.py` (Pillow). Regenerate with:

```bash
python tool/render_garments.py
```

Swap in real product photography or designer cut-outs by dropping transparent
PNGs over these same paths. Real user items are unaffected — they get their own
cut-outs from the background-removal service at capture time.

## Rendering rules (`lib/widgets/item_image.dart`)

`ItemImage` resolves a garment image in this priority order:

1. `processedBytes` — just-processed cut-out held in memory
2. `processedImageUrl` — stored cut-out (`assets/…`, a URL, or a storage path)
3. `localBytes` — the raw just-captured photo
4. `imagePath` — the raw original photo
5. a flat-lay silhouette in the item's colour (fallback)

Anything under `assets/` (or a `processedImageUrl`) is treated as a cut-out and
matted `contain`; a raw photo fills the card `cover`. A missing asset falls back
to the silhouette, so the grid never shows a broken image.

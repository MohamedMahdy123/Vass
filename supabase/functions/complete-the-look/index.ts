// complete-the-look — Vess missing-item → affiliate offers
//
// Takes a detected gap (query + price band) and returns real, shoppable
// products with affiliate deep links via the ShopStyle Collective Product API.
// Gated by SHOPSTYLE_PID: with no key it returns { configured:false } so the
// app falls back to its own mock offers. The gap is logged best-effort for
// analytics; a missing table never blocks offers.
//
// Swap-in note: any product/affiliate API (Skimlinks, ShopStyle, Amazon PA)
// fits behind this same contract — only mapToOffers() changes.

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

interface Offer {
  title: string; brand: string; retailer: string;
  price_cents: number; image_url: string | null; url: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "Not authenticated" }, 401);

    const body = await req.json();
    const query: string = (body.query ?? "").toString().trim();
    if (!query) return json({ error: "query is required" }, 400);
    const priceMin = Number(body.priceMin ?? 0);
    const priceMax = Number(body.priceMax ?? 100000);

    // Best-effort: log the suggestion for analytics. Never block on it.
    try {
      await supabase.from("missing_item_suggestions").insert({
        outfit_id: body.outfitId ?? null,
        slot: body.slot ?? null,
        descriptor: body.descriptor ?? null,
        reason: body.reason ?? null,
        source: "shop",
      });
    } catch (_) { /* table may not exist yet */ }

    const pid = Deno.env.get("SHOPSTYLE_PID");
    if (!pid) return json({ configured: false, offers: [] });

    const url = `https://api.shopstyle.com/api/v2/products?pid=${encodeURIComponent(pid)}` +
      `&fts=${encodeURIComponent(query)}&limit=12&sort=Popular`;
    const res = await fetch(url);
    if (!res.ok) return json({ configured: true, offers: [] }, 200);
    const data = await res.json();

    const offers = mapToOffers(data?.products ?? [], priceMin, priceMax);
    return json({ configured: true, offers });
  } catch (err) {
    console.error("complete-the-look failed", err);
    return json({ error: "Offer lookup failed" }, 500);
  }
});

function mapToOffers(products: any[], min: number, max: number): Offer[] {
  const mapped: Offer[] = products.map((p) => {
    const price = Number(p.salePrice ?? p.price ?? 0);
    const img = p.image?.sizes?.Best?.url ?? p.image?.sizes?.Large?.url ??
      p.image?.sizes?.Original?.url ?? null;
    return {
      title: (p.unbrandedName ?? p.brandedName ?? p.name ?? "").toString(),
      brand: (p.brand?.name ?? p.retailer?.name ?? "").toString(),
      retailer: (p.retailer?.name ?? p.brand?.name ?? "").toString(),
      price_cents: Math.round(price * 100),
      image_url: img,
      url: (p.clickUrl ?? "").toString(),
    };
  }).filter((o) => o.url && o.price_cents > 0);

  const inBand = mapped.filter((o) =>
    o.price_cents >= min * 100 && o.price_cents <= max * 100);
  const pool = inBand.length >= 3 ? inBand : mapped;
  return pool.slice(0, 3);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

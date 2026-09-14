// recommend — Vess "What should I wear?" (M0 skeleton)
//
// The hybrid recommender. Rules narrow the candidate set (deterministic, cheap,
// here on the server), then the LLM picks one outfit from the VALID set and
// explains why. The "why" is both the differentiator and the trust safety-net.
//
// Model: Claude Sonnet 5 — near-Opus reasoning on the trust-critical path, at
// ~half the cost; adaptive thinking on, medium effort (the rules already
// bounded the problem). (Product decision: see the PRD's AI-stack table.)

import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

interface Item {
  id: string;
  name: string;
  category?: string;
  color?: string;
  material?: string;
  pattern?: string;
  season?: string;
  occasion?: string;
  wear_count?: number;
}

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: { type: "string", description: "A short name for the look, e.g. 'The Quiet Professional'" },
    item_ids: { type: "array", items: { type: "string" }, description: "IDs of the chosen items" },
    reason: { type: "string", description: "One warm, concrete paragraph on why this outfit works today" },
  },
  required: ["title", "item_ids", "reason"],
};

// --- Rules-first narrowing (M3) ---------------------------------------------
// The deterministic gate that keeps the LLM from ever proposing an incoherent
// look. We drop pieces that fight the weather/occasion, then hand the model a
// bounded, coherent candidate set. The client already excludes disliked items.

const SLOT = (c = ""): string => {
  const s = c.toLowerCase();
  if (s.includes("dress")) return "Dress";
  if (/(outerwear|coat|jacket)/.test(s)) return "Outerwear";
  if (/(footwear|shoe|boot|sneaker)/.test(s)) return "Footwear";
  if (/(accessor|scarf|bag|hat)/.test(s)) return "Accessories";
  if (/(bottom|trouser|jean|pant|skirt|short)/.test(s)) return "Bottoms";
  return "Tops";
};

const formality = (o = ""): number => {
  const s = o.toLowerCase();
  if (/(formal|evening)/.test(s)) return 3;
  if (/(work|smart|business)/.test(s)) return 2;
  if (/(casual|everyday)/.test(s)) return 0;
  return 1;
};

const isWarm = (w = "") => /(warm|hot|sun|summer)/.test(w.toLowerCase());
const isCold = (w = "") => /(cold|snow|freez|winter|chill)/.test(w.toLowerCase());

function seasonFits(i: Item, weather?: string): boolean {
  const s = (i.season ?? "").toLowerCase();
  if (!s || s === "all") return true;
  if (isWarm(weather)) return s !== "winter";
  if (isCold(weather)) return s !== "summer";
  return true;
}

function narrowCandidates(items: Item[], occasion?: string, weather?: string): Item[] {
  const target = formality(occasion);

  // Weather/season filter, but never starve a slot: keep an item if dropping it
  // would empty its slot.
  const bySlot = new Map<string, Item[]>();
  for (const i of items) {
    const slot = SLOT(i.category);
    const list = bySlot.get(slot) ?? [];
    list.push(i);
    bySlot.set(slot, list);
  }

  const kept: Item[] = [];
  for (const [, list] of bySlot) {
    const fit = list.filter((i) => seasonFits(i, weather));
    const pool = fit.length > 0 ? fit : list; // don't empty the slot
    // Rank: closest formality first, then least-worn, then keep a healthy pool.
    pool.sort((a, b) => {
      const fa = Math.abs(formality(a.occasion) - target);
      const fb = Math.abs(formality(b.occasion) - target);
      if (fa !== fb) return fa - fb;
      return (a.wear_count ?? 0) - (b.wear_count ?? 0);
    });
    // Cap each slot so the prompt stays small but varied.
    kept.push(...pool.slice(0, 8));
  }

  // If it's warm, don't even offer heavy outerwear.
  return isWarm(weather) ? kept.filter((i) => SLOT(i.category) !== "Outerwear") : kept;
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

    // TODO(M4): enforce free-tier recommendation quota here.

    const { items, occasion, weather } = await req.json();
    if (!Array.isArray(items) || items.length === 0) {
      return json({ error: "items is required" }, 400);
    }

    const candidates = narrowCandidates(items, occasion, weather);

    const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });

    const message = await anthropic.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 3000,
      thinking: { type: "adaptive" },
      output_config: { effort: "medium", format: { type: "json_schema", schema: SCHEMA } },
      system:
        "You are Vess, a personal stylist. You build one outfit using ONLY the " +
        "items provided — never invent garments. A complete look needs a top and " +
        "bottom (or a dress) plus shoes; add outerwear when the weather calls for " +
        "it. Choose items whose colors and formality work together. Explain your " +
        "choice warmly and concretely in one short paragraph.",
      messages: [
        {
          role: "user",
          content:
            `Context — occasion: ${occasion ?? "everyday"}; weather: ${weather ?? "mild"}.\n\n` +
            `My wardrobe (candidates):\n${JSON.stringify(candidates, null, 2)}\n\n` +
            "Pick one outfit for today and tell me why.",
        },
      ],
    });

    const textBlock = message.content.find((b: { type: string }) => b.type === "text");
    const outfit = JSON.parse(textBlock?.text ?? "{}");

    return json({ outfit });
  } catch (err) {
    console.error("recommend failed", err);
    return json({ error: "Recommendation failed" }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// stylist — Vess conversational stylist with actionable intent routing
//
// Architecture ported from the formcraft chat stack: an auth-gated Edge
// Function calls the model with a strong system prompt + the user's wardrobe as
// bounded context, and returns a STRUCTURED response { reply, action } where
// `action` deep-links the Flutter app into the matching screen. The client
// renders `action` as a tappable card (see StylistAction). The app has a local
// fallback, so this is the "real AI" path when the ANTHROPIC_API_KEY is set.

import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

interface Item {
  id: string;
  name: string;
  category?: string;
  color?: string;
  season?: string;
  occasion?: string;
  favorite?: boolean;
}

interface Turn { role: "user" | "assistant"; text: string }

// The intent-routing contract. Keep these type names in sync with the Flutter
// StylistAction.fromJson parser.
const SYSTEM = `You are Vess, a warm, decisive personal stylist inside a wardrobe app.

You may ONLY reference garments from the user's wardrobe JSON below — never invent items. When you propose an outfit, build a complete look (a top and bottom, or a dress, plus shoes; add outerwear when it's cold) using real item ids from the wardrobe.

The app can deep-link the user into screens. ALWAYS reply as a single JSON object, no markdown, no code fences, matching exactly:
{
  "reply": "<one short, friendly paragraph; say why the pieces work>",
  "action": <one of the action objects below, or null>
}

Action objects (choose the ONE that best matches the user's intent, else null):
- Proposing a specific outfit:      {"type":"view_outfit","label":"See this look","item_ids":["<id>",...],"occasion":"<Work|Smart|Casual|Formal|null>"}
- User wants to compose/edit a look: {"type":"open_canvas","label":"Build a look"}
- User asks for their saved looks:   {"type":"open_outfits","label":"View My Outfits"}
- User asks to see one garment:      {"type":"open_item","label":"View <name>","item_id":"<id>"}
- User wants to try something on:     {"type":"open_tryon","label":"Open try-on"}
- User wants to browse their closet:  {"type":"open_closet","label":"Open my closet"}

Rules:
- item_ids and item_id MUST be ids that exist in the wardrobe JSON. If you can't ground them, use action null.
- If the wardrobe can't answer, say what's missing and use action null.
- Keep "reply" concise and plain-text (no markdown).`;

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

    const { message, items, history, constraints } = await req.json();
    if (typeof message !== "string" || !message.trim()) {
      return json({ error: "message is required" }, 400);
    }

    const wardrobe: Item[] = Array.isArray(items) ? items : [];
    const past: Turn[] = Array.isArray(history) ? history.slice(-8) : [];

    const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });

    const messages = [
      ...past
        .filter((t) => t.text && (t.role === "user" || t.role === "assistant"))
        .map((t) => ({ role: t.role, content: t.text })),
      {
        role: "user" as const,
        content: constraints
          ? `${message}\n\nConstraints: ${JSON.stringify(constraints)}`
          : message,
      },
    ];

    const reply = await anthropic.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 700,
      system: SYSTEM + "\n\nThe user's wardrobe (JSON):\n" + JSON.stringify(wardrobe),
      messages,
    });

    const textBlock = reply.content.find((b: { type: string }) => b.type === "text");
    const raw = (textBlock as { text?: string })?.text ?? "";
    return json(parseStructured(raw, wardrobe));
  } catch (err) {
    console.error("stylist failed", err);
    return json({ error: "Stylist failed" }, 500);
  }
});

// Parse the model's JSON reply, tolerating stray fences/prose (same discipline
// as the formcraft Ollama transport). Validates that any referenced item ids
// actually exist in the wardrobe; drops the action otherwise.
function parseStructured(raw: string, wardrobe: Item[]): { reply: string; action: unknown } {
  const ids = new Set(wardrobe.map((i) => i.id));
  const cleaned = raw.replace(/```json/gi, "").replace(/```/g, "").trim();
  const start = cleaned.indexOf("{");
  const end = cleaned.lastIndexOf("}");
  if (start !== -1 && end > start) {
    try {
      const obj = JSON.parse(cleaned.slice(start, end + 1));
      const replyText = typeof obj.reply === "string" && obj.reply.trim()
        ? obj.reply.trim()
        : cleaned;
      let action = obj.action ?? null;
      if (action && typeof action === "object") {
        if (Array.isArray(action.item_ids)) {
          action.item_ids = action.item_ids.filter((x: string) => ids.has(x));
          if (action.type === "view_outfit" && action.item_ids.length === 0) action = null;
        }
        if (action && action.type === "open_item" && !ids.has(action.item_id)) action = null;
      }
      return { reply: replyText, action };
    } catch { /* fall through */ }
  }
  return { reply: cleaned || "Sorry — try me again?", action: null };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

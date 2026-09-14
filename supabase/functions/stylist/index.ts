// stylist — Vess conversational stylist
//
// A free-form chat that answers styling questions using ONLY the user's own
// wardrobe as context. Claude Sonnet 5, kept concise and warm. The app has a
// local fallback, so this is the "real AI" path when the Anthropic key is set.

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

    const { message, items, history } = await req.json();
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
      { role: "user" as const, content: message },
    ];

    const reply = await anthropic.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 600,
      system:
        "You are Vess, a warm, decisive personal stylist. You may ONLY suggest " +
        "garments from the user's wardrobe below — never invent items. Build a " +
        "complete look (top and bottom, or a dress, plus shoes; outerwear when " +
        "it's cold). Be concise: one short, friendly paragraph, and say why the " +
        "pieces work together. If the wardrobe can't answer, say what's missing.\n\n" +
        "The user's wardrobe (JSON):\n" + JSON.stringify(wardrobe),
      messages,
    });

    const textBlock = reply.content.find((b: { type: string }) => b.type === "text");
    return json({ reply: (textBlock as { text?: string })?.text ?? "" });
  } catch (err) {
    console.error("stylist failed", err);
    return json({ error: "Stylist failed" }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

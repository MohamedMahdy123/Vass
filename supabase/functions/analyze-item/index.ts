// analyze-item — Vess AI photo tagging (M0 skeleton)
//
// Takes one garment photo and returns structured attributes. Runs SERVER-SIDE
// so the Anthropic API key never touches the app. The client uploads the photo
// to storage, then calls this with the base64 image; we return attributes the
// user reviews before saving.
//
// Model: Claude Haiku 4.5 — a bounded vision-classification task; cheapest tier,
// structured output. (Product decision: see the PRD's AI-stack table.)

import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

// Rich, structured tags — drive the AI stylist, weather matching and outfit
// assembly. Multi-value occasions / seasons / weather; primary+secondary colour.
const SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    name: { type: "string", description: "Short human name, e.g. 'Ribbed Wool Sweater'" },
    category: {
      type: "string",
      enum: ["Tops", "Bottoms", "Outerwear", "Footwear", "Accessories", "Dresses", "Other"],
    },
    sub_category: { type: "string", description: "Specific type, e.g. 'Oxford shirt', 'Chelsea boot'" },
    color_primary: { type: "string" },
    color_secondary: { type: ["string", "null"], description: "Second colour if any, else null" },
    fabric_type: { type: "string", description: "e.g. 'Cotton', 'Wool', 'Denim', 'Leather'" },
    pattern: { type: "string", description: "e.g. 'Solid', 'Striped', 'Checked'" },
    occasions: {
      type: "array",
      items: { type: "string", enum: ["Casual", "Work", "Smart", "Formal", "Party", "Active"] },
      description: "All occasions this piece suits",
    },
    seasons: {
      type: "array",
      items: { type: "string", enum: ["Spring", "Summer", "Autumn", "Winter", "All"] },
    },
    weather_tags: {
      type: "array",
      items: { type: "string", enum: ["Hot", "Warm", "Mild", "Cold", "Rain"] },
      description: "Weather conditions the piece is suitable for",
    },
    brand: { type: ["string", "null"], description: "Brand if legible, else null" },
  },
  required: [
    "name", "category", "sub_category", "color_primary", "color_secondary",
    "fabric_type", "pattern", "occasions", "seasons", "weather_tags", "brand",
  ],
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    // --- authenticate the caller (RLS boundary) --------------------------
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "Not authenticated" }, 401);

    // TODO(M4): enforce free-tier quota here before spending on the model.

    const { imageBase64, mediaType } = await req.json();
    if (!imageBase64) return json({ error: "imageBase64 is required" }, 400);

    const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY")! });

    const message = await anthropic.messages.create({
      model: "claude-haiku-4-5",
      max_tokens: 512,
      output_config: { format: { type: "json_schema", schema: SCHEMA } },
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: mediaType ?? "image/jpeg",
                data: imageBase64,
              },
            },
            {
              type: "text",
              text:
                "Identify this single clothing item and return its structured " +
                "attributes. List every occasion, season and weather condition it " +
                "genuinely suits (not just one). Give a primary colour and a " +
                "secondary colour only if there's a clear second colour. Only " +
                "claim a brand if it is clearly legible, else null.",
            },
          ],
        },
      ],
    });

    const textBlock = message.content.find((b: { type: string }) => b.type === "text");
    const attributes = JSON.parse(textBlock?.text ?? "{}");

    return json({ attributes });
  } catch (err) {
    console.error("analyze-item failed", err);
    return json({ error: "Analysis failed" }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

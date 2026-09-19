// analyze-item — Vess AI photo tagging (Google Gemini)
//
// Takes one garment photo and returns structured attributes. Runs SERVER-SIDE
// so the Gemini API key never touches the app. The client sends the base64
// image; we return { attributes } the user reviews before saving.
//
// Model: Gemini 1.5 Flash — a bounded vision-classification task; free tier,
// structured JSON output via responseSchema. Override with GEMINI_MODEL.
// (Switched from Claude to Gemini for a 100%-free vision path.)

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-1.5-flash";

// Gemini responseSchema (OpenAPI subset): uppercase types, `nullable`, enums on
// string items. Mirrors the attribute shape the capture flow reads.
const CATEGORIES = ["Tops", "Bottoms", "Outerwear", "Footwear", "Accessories", "Dresses", "Other"];
const OCCASIONS = ["Casual", "Work", "Smart", "Formal", "Party", "Active"];
const SEASONS = ["Spring", "Summer", "Autumn", "Winter", "All"];
const WEATHER = ["Hot", "Warm", "Mild", "Cold", "Rain"];

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    name: { type: "STRING", description: "Short human name, e.g. 'Ribbed Wool Sweater'" },
    category: { type: "STRING", enum: CATEGORIES },
    sub_category: { type: "STRING", description: "Specific type, e.g. 'Oxford shirt', 'Chelsea boot'" },
    color_primary: { type: "STRING" },
    color_secondary: { type: "STRING", nullable: true },
    fabric_type: { type: "STRING", description: "e.g. 'Cotton', 'Wool', 'Denim', 'Leather'" },
    pattern: { type: "STRING", description: "e.g. 'Solid', 'Striped', 'Checked'" },
    occasions: { type: "ARRAY", items: { type: "STRING", enum: OCCASIONS } },
    seasons: { type: "ARRAY", items: { type: "STRING", enum: SEASONS } },
    weather_tags: { type: "ARRAY", items: { type: "STRING", enum: WEATHER } },
    brand: { type: "STRING", nullable: true },
  },
  required: [
    "name", "category", "sub_category", "color_primary", "color_secondary",
    "fabric_type", "pattern", "occasions", "seasons", "weather_tags", "brand",
  ],
};

const PROMPT =
  "Identify this single clothing item and return its structured attributes as " +
  "JSON. List every occasion, season and weather condition it genuinely suits " +
  "(not just one). Give a primary colour and a secondary colour only if there's " +
  "a clear second colour (else null). Only claim a brand if it is clearly " +
  "legible (else null).";

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

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) return json({ error: "GEMINI_API_KEY not configured" }, 501);

    const { imageBase64, mediaType } = await req.json();
    if (!imageBase64) return json({ error: "imageBase64 is required" }, 400);

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;

    const geminiResp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [
              { inline_data: { mime_type: mediaType ?? "image/jpeg", data: imageBase64 } },
              { text: PROMPT },
            ],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
          temperature: 0.2,
        },
      }),
    });

    if (!geminiResp.ok) {
      const detail = await geminiResp.text();
      console.error("gemini generateContent failed", geminiResp.status, detail);
      return json({ error: `Gemini error ${geminiResp.status}`, detail }, 502);
    }

    const result = await geminiResp.json();
    const text = result?.candidates?.[0]?.content?.parts
      ?.map((p: { text?: string }) => p.text ?? "")
      .join("") ?? "";

    const attributes = parseJson(text);
    if (!attributes) {
      console.error("gemini returned no parseable JSON", text.slice(0, 500));
      return json({ error: "No attributes returned" }, 502);
    }

    return json({ attributes });
  } catch (err) {
    console.error("analyze-item failed", err);
    return json({ error: "Analysis failed" }, 500);
  }
});

// Gemini with responseMimeType=application/json returns raw JSON, but be
// defensive: strip any ```json fences / prose the model might still add.
function parseJson(text: string): Record<string, unknown> | null {
  const cleaned = text.replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
  try {
    return JSON.parse(cleaned);
  } catch (_) {
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(cleaned.slice(start, end + 1));
      } catch (_) { /* fall through */ }
    }
    return null;
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

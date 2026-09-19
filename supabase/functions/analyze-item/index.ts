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

// gemini-1.5-flash is retired for newer API keys (404). Default to a current
// model; if it 404s, we auto-discover a working flash model for this key.
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.0-flash";

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

    const payload = {
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
    };

    let geminiResp = await generate(GEMINI_MODEL, apiKey, payload);

    // Self-heal a 404 (model retired / not available for this key): discover a
    // working flash model this key actually has, then retry once.
    if (geminiResp.status === 404) {
      const fallback = await pickAvailableModel(apiKey);
      if (fallback) {
        console.warn(`gemini ${GEMINI_MODEL} 404 → retrying with ${fallback}`);
        geminiResp = await generate(fallback, apiKey, payload);
      }
    }

    if (!geminiResp.ok) {
      const detail = await geminiResp.text();
      console.error("gemini generateContent failed", geminiResp.status, detail);
      // Surface a diagnostic in `error` (the app shows this) so we can see the
      // real cause without an app rebuild: status, Gemini's message, and which
      // models this key can actually use.
      const diag = await diagnoseModels(apiKey);
      const msg = extractMessage(detail);
      return json({
        error: `Gemini ${geminiResp.status}: ${msg} | ${diag}`,
        detail,
      }, 502);
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

function generate(
  model: string,
  apiKey: string,
  payload: unknown,
): Promise<Response> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  return fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

// Ask the API which models THIS key can use and pick a vision-capable flash
// model that supports generateContent. Preference order favours fast+free tiers.
async function pickAvailableModel(apiKey: string): Promise<string | null> {
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`,
    );
    if (!res.ok) return null;
    const data = await res.json();
    const models: Array<{ name?: string; supportedGenerationMethods?: string[] }> =
      data?.models ?? [];
    const usable = models
      .filter((m) => (m.supportedGenerationMethods ?? []).includes("generateContent"))
      .map((m) => (m.name ?? "").replace(/^models\//, ""))
      .filter(Boolean);

    const prefer = [
      "gemini-2.0-flash",
      "gemini-2.5-flash",
      "gemini-flash-latest",
      "gemini-2.0-flash-001",
    ];
    for (const p of prefer) {
      if (usable.includes(p)) return p;
    }
    // Else any flash model, else any usable model at all.
    return usable.find((m) => m.includes("flash")) ?? usable[0] ?? null;
  } catch (_) {
    return null;
  }
}

// Diagnostic: report the ListModels HTTP status, or the usable model names, so
// a failed call explains itself in the app toast.
async function diagnoseModels(apiKey: string): Promise<string> {
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`,
    );
    if (!res.ok) return `ListModels HTTP ${res.status}`;
    const data = await res.json();
    const usable = (data?.models ?? [])
      .filter((m: { supportedGenerationMethods?: string[] }) =>
        (m.supportedGenerationMethods ?? []).includes("generateContent"))
      .map((m: { name?: string }) => (m.name ?? "").replace(/^models\//, ""))
      .slice(0, 8);
    return `usable=[${usable.join(", ")}]`;
  } catch (e) {
    return `ListModels failed: ${e}`;
  }
}

function extractMessage(detail: string): string {
  try {
    return (JSON.parse(detail)?.error?.message ?? detail).toString().slice(0, 180);
  } catch (_) {
    return detail.slice(0, 180);
  }
}

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

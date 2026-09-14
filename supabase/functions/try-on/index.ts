// try-on — Vess Virtual Try-On (T1)
//
// Renders a person wearing a garment. The person photo and the garment image
// come from the app (base64); we call FASHN through fal.ai server-side so the
// provider key never reaches the client, fetch the rendered image, and return
// it as base64 for the app to preview and persist.
//
// Engine: FASHN (fashion-specialized try-on) via fal.ai's unified API, so the
// model can be swapped by changing FAL_MODEL without re-plumbing. (Product
// decision: see the try-on engine evaluation.)

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const FAL_MODEL = Deno.env.get("FAL_MODEL") ?? "fal-ai/fashn/tryon/v1.6";

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

    // TODO(T3): enforce free-tier try-on quota here (usage_events kind='tryon').

    const {
      personImageBase64,
      garmentImageBase64,
      personMediaType = "image/jpeg",
      garmentMediaType = "image/jpeg",
      category = "auto",
    } = await req.json();

    if (!personImageBase64 || !garmentImageBase64) {
      return json({ error: "personImageBase64 and garmentImageBase64 are required" }, 400);
    }

    const falKey = Deno.env.get("FAL_KEY");
    if (!falKey) {
      // Not configured yet — the app falls back to its demo compositor.
      return json({ error: "Try-on engine not configured" }, 500);
    }

    const modelImage = `data:${personMediaType};base64,${personImageBase64}`;
    const garmentImage = `data:${garmentMediaType};base64,${garmentImageBase64}`;

    // Synchronous fal endpoint: blocks until the render is ready (or times out).
    const falRes = await fetch(`https://fal.run/${FAL_MODEL}`, {
      method: "POST",
      headers: {
        "Authorization": `Key ${falKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model_image: modelImage,
        garment_image: garmentImage,
        category, // 'auto' | 'tops' | 'bottoms' | 'one-pieces'
      }),
    });

    if (!falRes.ok) {
      const detail = await falRes.text();
      console.error("fal try-on failed", falRes.status, detail);
      return json({ error: "Try-on render failed" }, 502);
    }

    const out = await falRes.json();
    const resultUrl: string | undefined = out?.images?.[0]?.url ?? out?.image?.url;
    if (!resultUrl) return json({ error: "No image returned" }, 502);

    // Fetch the rendered image and hand it back as base64 so the client can
    // show it instantly and upload it to the private 'tryon' bucket.
    const imgRes = await fetch(resultUrl);
    const buf = new Uint8Array(await imgRes.arrayBuffer());
    const resultImageBase64 = base64Encode(buf);

    return json({
      model: FAL_MODEL,
      resultImageBase64,
      mediaType: imgRes.headers.get("content-type") ?? "image/png",
    });
  } catch (err) {
    console.error("try-on failed", err);
    return json({ error: "Try-on failed" }, 500);
  }
});

function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

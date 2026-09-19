// remove-bg — Vess background removal
//
// Takes one garment photo and returns a transparent PNG cut-out. Runs
// SERVER-SIDE so the fal.ai key never touches the app. The client sends the
// base64 image; we return { imageBase64 } of the cut-out (PNG with alpha).
//
// Provider: fal.ai BiRefNet (`fal-ai/birefnet`) — a state-of-the-art matting
// model that produces clean, hard-edged cut-outs for clothing on any
// background. Reliable + fast, unlike the free anonymous Spaces we used before.
//
// Best-effort by contract: on any provider/network failure we return a 502 and
// the client keeps the original photo — background removal enhances a wardrobe
// item, it never gates saving it.

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

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

    const falKey = Deno.env.get("FAL_KEY");
    if (!falKey) return json({ error: "Background removal not configured" }, 501);

    const { imageBase64, mediaType } = await req.json();
    if (!imageBase64) return json({ error: "imageBase64 is required" }, 400);

    // fal.ai accepts a data-URI directly as image_url — no separate upload step.
    const dataUri = `data:${mediaType ?? "image/jpeg"};base64,${imageBase64}`;

    // Synchronous run: fal.run blocks until the result is ready, so there's no
    // queue polling to manage. BiRefNet returns a PNG with a transparent alpha.
    const falResp = await fetch("https://fal.run/fal-ai/birefnet", {
      method: "POST",
      headers: {
        "Authorization": `Key ${falKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ image_url: dataUri }),
    });

    if (!falResp.ok) {
      console.error("fal.ai birefnet failed", falResp.status, await falResp.text());
      return json({ error: "Background removal failed" }, 502);
    }

    const result = await falResp.json();
    const url = result?.image?.url as string | undefined;
    if (!url) return json({ error: "No cut-out returned" }, 502);

    // fal may return either a hosted URL or an inline data-URI. Handle both.
    let cutBase64: string;
    if (url.startsWith("data:")) {
      cutBase64 = url.slice(url.indexOf(",") + 1);
    } else {
      const img = await fetch(url);
      if (!img.ok) return json({ error: "Cut-out fetch failed" }, 502);
      const buf = new Uint8Array(await img.arrayBuffer());
      cutBase64 = base64Encode(buf);
    }

    return json({ imageBase64: cutBase64, mediaType: "image/png" });
  } catch (err) {
    console.error("remove-bg failed", err);
    return json({ error: "Background removal failed" }, 500);
  }
});

// Chunked base64 encoder — avoids the call-stack blowup of
// String.fromCharCode(...bigArray) on large images.
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

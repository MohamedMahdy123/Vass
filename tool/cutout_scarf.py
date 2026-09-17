"""Cut out a garment photo on a transparent background using the free
not-lain/background-removal Hugging Face Space (the same AI model the app's
BackgroundRemovalService uses). Saves a transparent PNG asset.

Usage: python tool/cutout_scarf.py <image_url> <out_path>
"""
import io
import json
import sys
import time

import requests

HOST = "https://not-lain-background-removal.hf.space"


def main(src_url, out_path):
    print("downloading source:", src_url)
    img = requests.get(src_url, timeout=60)
    img.raise_for_status()
    print("  got", len(img.content), "bytes")

    # 1) upload
    up = requests.post(
        f"{HOST}/gradio_api/upload",
        files={"files": ("scarf.jpg", io.BytesIO(img.content), "image/jpeg")},
        timeout=120,
    )
    up.raise_for_status()
    path = up.json()[0]
    print("uploaded ->", path)

    # 2) call the /png endpoint
    body = {"data": [{"path": path, "meta": {"_type": "gradio.FileData"}}]}
    call = requests.post(
        f"{HOST}/gradio_api/call/png",
        headers={"content-type": "application/json"},
        data=json.dumps(body),
        timeout=120,
    )
    call.raise_for_status()
    event_id = call.json().get("event_id")
    print("event_id:", event_id)
    if not event_id:
        print("no event_id; response:", call.text[:400])
        return 2

    # 3) stream the result (SSE)
    r = requests.get(
        f"{HOST}/gradio_api/call/png/{event_id}", stream=True, timeout=240
    )
    current = None
    result_url = None
    for raw in r.iter_lines(decode_unicode=True):
        if raw is None:
            continue
        line = raw.strip()
        if line.startswith("event:"):
            current = line[6:].strip()
        elif line.startswith("data:"):
            payload = line[5:].strip()
            if current == "error":
                print("SPACE ERROR (likely ZeroGPU quota):", payload[:300])
                return 3
            if current == "complete":
                result_url = extract_url(json.loads(payload))
                break
    if not result_url:
        print("no result url found")
        return 4

    if result_url.startswith("/"):
        result_url = HOST + result_url
    print("result:", result_url)

    out = requests.get(result_url, timeout=120)
    out.raise_for_status()
    with open(out_path, "wb") as f:
        f.write(out.content)
    print("wrote", out_path, len(out.content), "bytes")
    return 0


def extract_url(node):
    if isinstance(node, str):
        return node if node.startswith(("http", "/")) else None
    if isinstance(node, dict):
        for key in ("url", "path"):
            v = node.get(key)
            if isinstance(v, str) and (v.startswith("http") or v.startswith("/")):
                return v if v.startswith("http") else f"/gradio_api/file={v}"
        return None
    if isinstance(node, list):
        for n in node:
            u = extract_url(n)
            if u:
                return u
    return None


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))

#!/usr/bin/env python3
"""Generate one image through Leonardo's v2 API with a partner model.

The A2gent `leonardo_generate_image` tool only speaks the v1 API (Leonardo's own
models). The v2 API also serves Nano Banana (`gemini-2.5-flash-image`) and OpenAI
(`gpt-image-1.5`, `gpt-image-1` needs `--quality`). The key is read from
LEONARDO_API_KEY or the local A2gent integrations database, never written out.

Usage: generate_leonardo_v2_image.py MODEL WIDTH HEIGHT OUT.png "prompt"
Nano Banana sizes: width in 832/864/896/1024/1152/1184/1248/1344/1536,
height in 672/768/832/864/896/1024/1184/1248/1344 (e.g. 832x1248 portrait).
"""
import json
import os
import sqlite3
import sys
import time
import urllib.request
from pathlib import Path

DB = Path.home() / ".local/share/aagent/aagent.db"


def _key() -> str:
    if os.environ.get("LEONARDO_API_KEY"):
        return os.environ["LEONARDO_API_KEY"]
    row = sqlite3.connect(DB).execute(
        "SELECT config FROM integrations WHERE provider='leonardo' AND enabled=1"
    ).fetchone()
    return next(v for k, v in json.loads(row[0]).items() if "key" in k.lower())


def main() -> int:
    model, w, h, out, prompt = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5]
    head = {"Authorization": "Bearer " + _key(), "Content-Type": "application/json"}

    def call(url, body=None):
        return json.loads(urllib.request.urlopen(urllib.request.Request(url, body, head), timeout=120).read())

    params = {"width": w, "height": h, "prompt": prompt, "quantity": 1}
    if model.startswith("gpt-image"):
        params["quality"] = "HIGH"
    gid = call(
        "https://cloud.leonardo.ai/api/rest/v2/generations",
        json.dumps({"model": model, "parameters": params, "public": False}).encode(),
    )["generate"]["generationId"]
    for _ in range(60):
        time.sleep(4)
        g = call("https://cloud.leonardo.ai/api/rest/v1/generations/" + gid)["generations_by_pk"]
        if g["status"] == "COMPLETE":
            # The CDN rejects urllib's default agent with 403.
            req = urllib.request.Request(g["generated_images"][0]["url"], headers={"User-Agent": "Mozilla/5.0"})
            Path(out).write_bytes(urllib.request.urlopen(req).read())
            print("saved", out)
            return 0
        if g["status"] == "FAILED":
            break
    print("generation failed", gid)
    return 1


if __name__ == "__main__":
    sys.exit(main())

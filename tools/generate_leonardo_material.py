#!/usr/bin/env python3
"""Submit and poll Leonardo material-plate generations.

The A2gent Cursor adapter does not expose `leonardo_generate_image`. This
helper talks to the Leonardo REST API with the same request shape the
integration tool uses, then writes a prompt sidecar next to the raw source so
the plate can be iterated later.

The API key is read from LEONARDO_API_KEY or from the local A2gent
integrations database. It is never written into the repository.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API_BASE = "https://cloud.leonardo.ai/api/rest/v1"
DEFAULT_MODEL = "05ce0082-2d80-4a2d-8653-4d1c85e2418e"
AAGENT_DB = Path.home() / ".local/share/aagent/aagent.db"


def _api_key_from_aagent() -> str:
    if not AAGENT_DB.is_file():
        return ""
    con = sqlite3.connect(AAGENT_DB)
    try:
        row = con.execute(
            "SELECT config FROM integrations WHERE provider = 'leonardo' AND enabled = 1"
        ).fetchone()
    finally:
        con.close()
    if not row:
        return ""
    config = json.loads(row[0])
    return str(config.get("api_key") or "").strip()


def resolve_api_key(explicit: str) -> str:
    import os

    return explicit.strip() or os.environ.get("LEONARDO_API_KEY", "").strip() or _api_key_from_aagent()


def _request(method: str, url: str, api_key: str, payload: dict | None = None) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {api_key}")
    req.add_header("Accept", "application/json")
    if payload is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Leonardo HTTP {exc.code}: {body}") from exc


def create_generation(api_key: str, payload: dict) -> str:
    try:
        body = _request("POST", f"{API_BASE}/generations", api_key, payload)
    except RuntimeError as exc:
        # Some models reject tiling or presetStyle; retry the material-only body.
        message = str(exc)
        if payload.get("tiling") or payload.get("presetStyle"):
            retry = dict(payload)
            retry.pop("tiling", None)
            retry.pop("presetStyle", None)
            body = _request("POST", f"{API_BASE}/generations", api_key, retry)
        else:
            raise
        if "tiling" in message or "presetStyle" in message:
            pass
    generation = body.get("sdGenerationJob") or body.get("generation") or {}
    generation_id = str(generation.get("generationId") or generation.get("id") or "")
    if not generation_id:
        raise RuntimeError(f"Leonardo create response missing generation id: {body}")
    return generation_id


def wait_for_generation(api_key: str, generation_id: str, timeout_s: float = 300.0) -> dict:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        body = _request("GET", f"{API_BASE}/generations/{generation_id}", api_key)
        generations = body.get("generations_by_pk") or body.get("generation") or body
        status = str(generations.get("status") or "").upper()
        if status in {"COMPLETE", "FAILED"}:
            return generations
        time.sleep(3)
    raise TimeoutError(f"Leonardo generation {generation_id} timed out")


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (compatible; rebel-reval-texture-pipeline/1.0)",
            "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        },
    )
    with urllib.request.urlopen(req, timeout=60) as response:
        destination.write_bytes(response.read())


def generate_plate(api_key: str, spec: dict) -> dict:
    payload = {
        "prompt": spec["prompt"],
        "negative_prompt": spec.get("negative_prompt", ""),
        "modelId": spec.get("model_id", DEFAULT_MODEL),
        "width": int(spec.get("width", 1024)),
        "height": int(spec.get("height", 1024)),
        "num_images": int(spec.get("num_images", 2)),
        "tiling": True,
    }
    generation_id = create_generation(api_key, payload)
    print(f"LEONARDO_GENERATION_ID={generation_id}", flush=True)
    result = wait_for_generation(api_key, generation_id)
    if str(result.get("status") or "").upper() != "COMPLETE":
        raise RuntimeError(f"Leonardo generation {generation_id} failed: {result}")
    images = result.get("generated_images") or []
    if not images:
        raise RuntimeError(f"Leonardo generation {generation_id} returned no images")

    out_dir = ROOT / spec["output_dir"]
    out_dir.mkdir(parents=True, exist_ok=True)
    saved: list[str] = []
    for index, image in enumerate(images, start=1):
        url = str(image.get("url") or "")
        if not url:
            continue
        path = out_dir / f"candidate_{index}.jpg"
        download(url, path)
        saved.append(str(path.relative_to(ROOT)))

    prompt_path = out_dir / "prompt.json"
    record = {
        "id": spec["id"],
        "family": spec["family"],
        "map_type": spec.get("map_type", "albedo"),
        "kind": "leonardo_material_plate",
        "target": spec["target"],
        "source": saved[0] if saved else "",
        "candidates": saved,
        "prompt": spec["prompt"],
        "negative_prompt": spec.get("negative_prompt", ""),
        "model_id": spec.get("model_id", DEFAULT_MODEL),
        "model_name": spec.get("model_name", "Leonardo configured realism model"),
        "width": int(spec.get("width", 1024)),
        "height": int(spec.get("height", 1024)),
        "tiling": True,
        "generation_id": generation_id,
        "selected_candidate": 1,
        "processor": spec.get("processor", "tools/process_leonardo_terrain_textures.py"),
        "style_refs": spec.get(
            "style_refs",
            ["docs/ART_BIBLE.md", "docs/MATERIAL_STYLE_LOCK_KIT.md"],
        ),
        "notes": spec.get("notes", ""),
    }
    prompt_path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    (out_dir / "state.json").write_text(
        json.dumps(
            {
                "asset_id": spec["id"],
                "route": "leonardo_material_plate",
                "stage": "generated",
                "job_id": generation_id,
                "decision": "review",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return record


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--api-key", default="")
    args = parser.parse_args()
    api_key = resolve_api_key(args.api_key)
    if not api_key:
        raise SystemExit("Leonardo API key not found. Set LEONARDO_API_KEY.")
    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    record = generate_plate(api_key, spec)
    print(json.dumps({"generation_id": record["generation_id"], "candidates": record["candidates"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

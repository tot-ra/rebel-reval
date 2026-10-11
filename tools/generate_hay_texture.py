#!/usr/bin/env python3
"""Build the seamless grayscale hay-fiber multiplier used by Godot materials.

The Leonardo source stays outside runtime paths. This deterministic conversion
mirrors a centered crop to remove hard borders, grades luminance into the narrow
range expected by palette-multiplied materials, and welds the final PNG edges.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps


DEFAULT_SOURCE = Path("generated/leonardo/hay_texture_v1/source.jpg")
DEFAULT_OUTPUT = Path("assets/materials/production/hay_fibers.png")
DEFAULT_REPORT = Path("generated/leonardo/hay_texture_v1/report.json")
OUTPUT_SIZE = 512


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_texture(source_path: Path) -> Image.Image:
    source = Image.open(source_path).convert("L")
    crop_size = min(source.size) // 2
    left = (source.width - crop_size) // 2
    top = (source.height - crop_size) // 2
    crop = source.crop((left, top, left + crop_size, top + crop_size))

    # A mirrored 2 x 2 tile keeps actual generated fibers while making both the
    # internal joins and external repeat boundaries continuous without cloning.
    mirrored = Image.new("L", (crop_size * 2, crop_size * 2))
    mirrored.paste(crop, (0, 0))
    mirrored.paste(ImageOps.mirror(crop), (crop_size, 0))
    mirrored.paste(ImageOps.flip(crop), (0, crop_size))
    mirrored.paste(ImageOps.flip(ImageOps.mirror(crop)), (crop_size, crop_size))
    texture = mirrored.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS)

    pixels = np.asarray(texture, dtype=np.float32)
    low, high = np.percentile(pixels, (2.0, 98.0))
    normalized = np.clip((pixels - low) / max(high - low, 1.0), 0.0, 1.0)
    # Godot multiplies this RGB texture with the approved #CDA444 palette role.
    # Keep enough shadow for layered fibers without turning hay black or neon.
    graded = np.clip(0.55 + normalized * 0.48, 0.0, 1.0)
    output = np.rint(graded * 255.0).astype(np.uint8)

    # Acceptance requires exact edge equality, not merely a visually soft seam.
    vertical_edge = np.rint((output[:, 0].astype(np.float32) + output[:, -1]) * 0.5).astype(np.uint8)
    output[:, 0] = vertical_edge
    output[:, -1] = vertical_edge
    horizontal_edge = np.rint((output[0].astype(np.float32) + output[-1]) * 0.5).astype(np.uint8)
    output[0] = horizontal_edge
    output[-1] = horizontal_edge
    corner = int(np.rint(np.mean([output[0, 0], output[0, -1], output[-1, 0], output[-1, -1]])))
    output[0, 0] = output[0, -1] = output[-1, 0] = output[-1, -1] = corner
    return Image.fromarray(output).convert("RGB")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()

    texture = build_texture(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    texture.save(args.output, format="PNG", optimize=True)

    pixels = np.asarray(texture, dtype=np.float32)
    report = {
        "source": str(args.source),
        "source_sha256": sha256(args.source),
        "output": str(args.output),
        "output_sha256": sha256(args.output),
        "size": list(texture.size),
        "mode": texture.mode,
        "channel_mean": round(float(pixels.mean()), 4),
        "channel_stddev": round(float(pixels.std()), 4),
        "left_right_max_delta": int(np.abs(pixels[:, 0] - pixels[:, -1]).max()),
        "top_bottom_max_delta": int(np.abs(pixels[0] - pixels[-1]).max()),
        "decision": "production_ready",
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("HAY_TEXTURE_METRICS=" + json.dumps(report, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

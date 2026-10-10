#!/usr/bin/env python3
"""Regenerate the animal concept art with Leonardo Nano Banana.

Same subjects as gen_animal_concept_art.py (PROMPTS), but rendered in the
cinematic low-key look of the character concept art (docs/concept/characters):
moody directional light, rich textures, muted earth palette with one warm accent.
Usage: gen_animal_concept_art_leonardo.py [--force] [name ...]
Writes docs/ANIMALS-AND-BIRDS/images/<name>.jpg (landscape 1248x832 -> jpg).
"""
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from gen_animal_concept_art import PROMPTS  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "docs/ANIMALS-AND-BIRDS/images"
GEN = ROOT / "tools/generate_leonardo_v2_image.py"
MODEL = "gemini-2.5-flash-image"

STYLE = (
    "Cinematic photorealistic wildlife portrait for a dark medieval Baltic history game, "
    "Reval Estonia 1343: {subject}. Moody low-key directional light, subject sharp with "
    "extremely detailed fur or feathers and skin texture, shallow depth of field, soft "
    "atmospheric background, muted earthy palette of moss green, grey, umber and soot "
    "with one warm amber highlight, subtle film grain, the same realistic dramatic look "
    "as a gritty character portrait. No people, no text, no watermark, no border."
)


def render(name: str) -> str:
    out = OUT_DIR / f"{name}.jpg"
    with tempfile.TemporaryDirectory() as td:
        png = Path(td) / f"{name}.png"
        for _ in range(2):
            r = subprocess.run([sys.executable, str(GEN), MODEL, "1248", "832", str(png),
                                STYLE.format(subject=PROMPTS[name])],
                               capture_output=True, text=True)
            if r.returncode == 0 and png.exists():
                subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "85",
                                str(png), "--out", str(out)], check=True, capture_output=True)
                return f"ok {name}"
        return f"FAIL {name}: {r.stdout.strip()} {r.stderr.strip()[-200:]}"


def main() -> int:
    args = [a for a in sys.argv[1:] if a != "--force"]
    names = args or sorted(PROMPTS)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as ex:
        results = list(ex.map(render, names))
    print("\n".join(results))
    return 1 if any(r.startswith("FAIL") for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())

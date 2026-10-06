"""Detect eye, nose-tip and mouth pixels on a generated frontal portrait.

    python3 tools/assets/realistic_humans/portrait_landmarks.py <name> [...]

The portraits are framed by generate_portraits.py (frontal, centred, even
light), so simple image cues suffice: the eye is the iris catchlight (the
brightest small spot inside a dark disc) in each upper-face half, the
nostrils are the darkest short row under the eyes, and the lip line is the
darkest row between nostrils and chin. Writes `landmarks` into the
character's reference/portrait.json; build_human.py reads it.
"""
from pathlib import Path
import json
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]


def _box_mean(a, r):
    c = np.cumsum(np.cumsum(np.pad(a, ((r + 1, r), (r + 1, r)), mode="edge"), 0), 1)
    return (c[2 * r + 1:, 2 * r + 1:] - c[:-2 * r - 1, 2 * r + 1:] - c[2 * r + 1:, :-2 * r - 1]
            + c[:-2 * r - 1, :-2 * r - 1]) / (2 * r + 1) ** 2


def detect(path):
    img = np.asarray(Image.open(path).convert("L"), dtype=np.float64) / 255.0
    h, w = img.shape
    cx = w // 2
    # Eyes: catchlight = bright pixel with a dark iris ring around it, searched
    # where framed eyes sit and paired at the same height.
    # Iris ~20 px radius: the catchlight sits in a dark disc that size, with
    # the bright lower-lid/cheek skin below it. A brow highlight has the dark
    # eye below it instead.
    iris = _box_mean(img, 9)
    below = np.roll(_box_mean(img, 9), -40, axis=0)  # value 40 px below
    score = img - 2.5 * iris + 1.2 * below
    y0, y1 = int(h * 0.28), int(h * 0.41)
    def best(lo, hi):
        sub = score[y0:y1, lo:hi]
        y, x = np.unravel_index(np.argmax(sub), sub.shape)
        return [lo + int(x), y0 + int(y)]
    eye_l = best(cx + 60, cx + 220)  # image right = character's left
    eye_r = best(cx - 220, cx - 60)
    if abs(eye_l[1] - eye_r[1]) > 18:  # a false catchlight: mirror the stronger eye
        l_score = score[eye_l[1], eye_l[0]]
        r_score = score[eye_r[1], eye_r[0]]
        if l_score >= r_score:
            eye_r = [2 * cx - eye_l[0], eye_l[1]]
        else:
            eye_l = [2 * cx - eye_r[0], eye_r[1]]
    eyes = [eye_l, eye_r]
    eye_y = (eye_l[1] + eye_r[1]) / 2
    span = eye_l[0] - eye_r[0]
    # Measured on the clean-shaven portraits: nostrils ~0.72 and lip line ~1.21
    # interpupillary spans below the eyes. Search only near those, so a
    # moustache cannot pass for either.
    strip = _box_mean(img, 3)[:, cx - int(span * 0.35):cx + int(span * 0.35)].mean(axis=1)
    lo, hi = int(eye_y + span * 0.58), int(eye_y + span * 0.84)
    nostril = lo + int(np.argmin(strip[lo:hi]))
    nose_tip = [cx, nostril - int(span * 0.06)]
    lips = _box_mean(img, 2)[:, cx - int(span * 0.18):cx + int(span * 0.18)].mean(axis=1)
    lo, hi = int(eye_y + span * 1.1), int(eye_y + span * 1.32)
    mouth = [cx, lo + int(np.argmin(lips[lo:hi]))]
    return {"eye_l": eyes[0], "eye_r": eyes[1], "nose_tip": nose_tip, "mouth": mouth}


def main(names):
    for name in names:
        ref = ROOT / f"assets/characters/realistic/{name}/reference"
        marks = detect(ref / "portrait.png")
        meta = json.loads((ref / "portrait.json").read_text())
        meta["landmarks"] = marks
        (ref / "portrait.json").write_text(json.dumps(meta, indent=2) + "\n")
        print(name, marks)


if __name__ == "__main__":
    main(sys.argv[1:])

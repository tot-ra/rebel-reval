"""Blend the donor MPFB face albedo into the Meshy-baked albedo (R-1874).

The scan bake leaves seams and stretched texels around the nose, nostrils and
mouth. In the nose/mouth ellipse (MPFB UV layout, 1024 px) the donor albedo is
tinted to the scan's low-frequency colour and blended over the scan with a soft
mask. Eye discs are excluded so the lid fill and scan brows are kept.

  python3 blend_donor_face.py DONOR.png SCAN.png OUT.png
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

CENTER, RX, RY = (900.0, 531.0), 50.0, 55.0
EYES = [(857.0, 493.0), (857.0, 566.0)]
EYE_R = 20.0
FEATHER = 0.5


def blur(a, s):
    img = Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).filter(ImageFilter.GaussianBlur(s))
    return np.asarray(img, np.float32) / 255


def main(donor_p, scan_p, out_p):
    d = np.asarray(Image.open(donor_p).convert("RGB"), np.float32) / 255
    s = np.asarray(Image.open(scan_p).convert("RGB"), np.float32) / 255
    h, w = s.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.hypot((xx - CENTER[0]) / RX, (yy - CENTER[1]) / RY)
    m = np.clip((1 - r) / FEATHER, 0, 1)
    for ex, ey in EYES:
        e = np.hypot(xx - ex, yy - ey) / EYE_R
        m *= np.clip((e - 0.8) / 0.8, 0, 1)
    m = m * m * (3 - 2 * m) * 0.9
    # Donor tinted to the scan's low-frequency colour, donor keeps fine detail.
    # Skin ring around the mask gives the tint so the lip colour stays the donor's.
    ring = ((r > 1.15) & (r < 1.6)).astype(np.float32)[..., None]
    tint = (s * ring).sum((0, 1)) / (d * ring).sum((0, 1))
    dt = np.clip(d * tint, 0, 1)
    # Flatten donor speckle slightly (freckles/specular read as noise at 1024 px).
    dt = dt * 0.35 + blur(dt, 1.5) * 0.65
    out = s * (1 - m[..., None]) + dt * m[..., None]
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(out_p)


if __name__ == "__main__":
    main(*sys.argv[1:4])

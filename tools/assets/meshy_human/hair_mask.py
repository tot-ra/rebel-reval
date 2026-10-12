"""Hair inpaint mask for a front A-pose reference (white = repaint).

  python3 tools/assets/meshy_human/hair_mask.py --image build/<char>/<char>_base_body.png \
      --hair 322,0,512,195 --face 372,66,460,192 [--braid 425,110,498,245] \
      --out build/<char>/<char>_hair_mask.png --preview build/<char>/mask_preview.png

Boxes are x0,y0,x1,y1 in source pixels: --hair is the ellipse over the whole
hairline and loose strands, --face the ellipse that must stay untouched (keep
the eyes and brows inside it), --braid an optional rectangle for a braid or bun
behind the neck. Run the inpaint twice with a slightly wider mask if wisps survive.
"""

import argparse

from PIL import Image, ImageChops, ImageDraw, ImageFilter


def box(s):
    return tuple(int(v) for v in s.split(","))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--image", required=True)
    p.add_argument("--hair", type=box, required=True)
    p.add_argument("--face", type=box, required=True)
    p.add_argument("--braid", type=box)
    p.add_argument("--blur", type=float, default=5.0)
    p.add_argument("--out", required=True)
    p.add_argument("--preview")
    a = p.parse_args()
    src = Image.open(a.image).convert("RGB")
    mask = Image.new("L", src.size, 0)
    d = ImageDraw.Draw(mask)
    d.ellipse(a.hair, fill=255)
    if a.braid:
        d.rectangle(a.braid, fill=255)
    face = Image.new("L", src.size, 0)
    ImageDraw.Draw(face).ellipse(a.face, fill=255)
    mask = ImageChops.subtract(mask, face).filter(ImageFilter.GaussianBlur(a.blur))
    mask.save(a.out)
    if a.preview:
        red = Image.new("RGB", src.size, (255, 0, 0))
        Image.composite(Image.blend(src, red, 0.5), src, mask).save(a.preview)


main()

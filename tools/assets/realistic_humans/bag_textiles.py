"""Bag leathers for the citizen scrips (task R-2034, docs/SYSTEMS/CITIZEN_WARDROBE.md).

Two crowd cloth grades beside the ones in textiles.py, written the same way
(tileable, near-neutral albedo multiplied by the garment colour, 512 px):

- `leather_tooled`: vegetable-tanned leather with a blind-tooled diaper (incised
  diagonal lattice, a stamped ring in each lozenge), the burgher's and merchant's
  scrip (p2/p3). Lattice and ring stamps are the commonest decoration on 13th-14th c.
  leather finds (sheaths, cases, purses) from Baltic and North German towns.
- `rawhide`: untanned, scraped hide dried stiff: pale, translucent-mottled, with
  hair follicles, vein ghosts and a waxy sheen, the poor man's scrip and strap (p1).

    python3 tools/assets/realistic_humans/bag_textiles.py

Tiles (metres) are mirrored in CitizenWardrobe.GRADE_TILE (scripts/city/citizen_wardrobe.gd).
"""
import numpy as np

import textiles as tx

GRADE_TILE_METRES = {"leather_tooled": 0.11, "rawhide": 0.20}


def _distance_to_lines(t, count):
    """Distance (in periods, 0..0.5) from coordinate t to the nearest of `count` lines per tile."""
    f = t * count
    return np.abs(f - np.round(f))


def leather_tooled():
    albedo, _, orm_map = tx.leather()
    u, v = tx.grid()
    grain = tx.periodic_noise(tx.SIZE, 260, 8, power=0.6)
    pores = np.clip(tx.periodic_noise(tx.SIZE, 420, 9, power=0.2), -1, -0.55) + 0.55
    # Diaper: two families of diagonal grooves, 6 lozenges per tile edge (about 1.8 cm).
    # u + v and u - v times an integer count stay periodic over the tile.
    cells = 6
    wobble = tx.periodic_noise(tx.SIZE, 24, 70) * 0.006
    d1 = _distance_to_lines(u + v + wobble, cells)
    d2 = _distance_to_lines(u - v + wobble, cells)
    groove = np.exp(-(np.minimum(d1, d2) / 0.045) ** 2)
    # Ring stamp at each lozenge centre: centres sit half a period off both line families.
    ring_r = np.hypot(d1 - 0.5, d2 - 0.5)
    ring = np.exp(-((ring_r - 0.16) / 0.035) ** 2)
    dot = np.exp(-(ring_r / 0.05) ** 2)
    stamp = np.clip(groove + 0.8 * ring + 0.5 * dot, 0, 1)
    height = grain * 0.3 + pores * 1.2 - stamp * 2.2
    # Tooling darkens and burnishes the leather it presses (wet-moulded lines read dark).
    albedo = albedo * (1.0 - 0.42 * stamp)[..., None]
    rough = np.clip(orm_map[..., 1] - 0.08 - 0.18 * stamp, 0.25, 0.95)
    return albedo, tx.height_to_normal(height, 3.0), tx.orm(tx.cavity(height), rough, 0.0)


def rawhide():
    size = tx.SIZE
    mottle = tx.periodic_noise(size, 6, 80, power=1.2)
    cloud = tx.periodic_noise(size, 22, 81)
    # Vein ghosts: a few faint branching lines, only where a low-frequency mask lets them.
    veins = np.abs(tx.periodic_noise(size, 16, 82, power=1.1))
    veins = np.clip(1.0 - veins * 30.0, 0, 1) ** 2 * np.clip(tx.periodic_noise(size, 4, 86) * 2.0, 0, 1)
    follicles = np.clip(tx.periodic_noise(size, 460, 83, power=0.1) * 4.0 - 2.9, 0, 1)
    wrinkles = tx.periodic_noise(size, 55, 84, power=0.7)
    scrape = tx.periodic_noise(size, 90, 85)
    height = wrinkles * 0.5 + scrape * 0.15 - follicles * 0.6 - veins * 0.3
    # Translucent patches (thin, scraped hide) read lighter and yellower; thick ones darker.
    tone = 0.74 + 0.1 * mottle + 0.04 * cloud - 0.08 * veins - 0.3 * follicles
    albedo = np.stack([tone, tone * 0.95, tone * 0.84 - 0.04 * mottle], -1)
    # Dried hide is waxy and hard: glossier than tanned leather, duller where scraped.
    rough = np.clip(0.48 + 0.1 * cloud + 0.12 * np.abs(scrape) + 0.15 * follicles, 0.25, 0.9)
    return albedo, tx.height_to_normal(height, 1.8), tx.orm(tx.cavity(height), rough, 0.0)


GRADES = {"leather_tooled": leather_tooled, "rawhide": rawhide}


def write_all():
    tx.OUT.mkdir(parents=True, exist_ok=True)
    half = int(round(np.log2(tx.SIZE // tx.GRADE_SIZE)))
    for grade, make in GRADES.items():
        tx._write_set(tx.texture_paths(grade, tx.GRADE_SIZE), *make(), half)
        print("wrote grade", grade)


if __name__ == "__main__":
    write_all()

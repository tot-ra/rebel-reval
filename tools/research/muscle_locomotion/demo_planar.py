"""GIF demo of the planar generalist biped on six body types (shaded 3D view of the 2D simulation)."""
import sys, json, argparse
import numpy as np
import viz
from sim import Sim
from creature import build_mjcf
import presets
from render import NAMED

ap = argparse.ArgumentParser(); ap.add_argument("result"); ap.add_argument("--fr", type=float, default=0.35)
ap.add_argument("--out", required=True); ap.add_argument("--seconds", type=float, default=5.0)
a = ap.parse_args()
j = json.load(open(a.result)); p = np.array(j["params"]); name = j["creature"]
tiles = []
for label, kw in NAMED[name].items():
    s = Sim(getattr(presets, name)(presets.Body(**kw)))
    r = s.rollout(p, T=12.0, froude=a.fr, record=True)
    traj = r["traj"]
    # last `seconds` of the episode, after the gait has settled
    n = int(a.seconds / 0.02); traj = traj[-n:] if r["alive"] >= 1 else traj
    sc = viz.Scene(build_mjcf(s.c), 300, 220)
    qp = np.zeros(sc.model.nq); frames = []
    for fr in traj[::2]:
        qp[0] = fr["x"]; qp[1] = fr["z"]; qp[2] = fr["pitch"]
        for qa, q in zip(s.jqpos, fr["q"]): qp[qa] = q
        img = sc.frame(qp, (fr["x"], 0), dist=3.2 * max(s.c.body.get("size", 1), 0.7), azimuth=70, elevation=-10, lookz=0.55 * s.stand)
        frames.append(viz.caption(img, label, f"{r['speed']:.2f} m/s, {r['freq']:.1f} Hz" + ("" if r["alive"] >= 1 else "  FELL")))
    sc.close(); del sc
    tiles.append(frames)
    print(label, len(frames), "frames", flush=True)
L = min(len(f) for f in tiles)
imgs = [viz.grid([t[k] for t in tiles], 3) for k in range(L)]
viz.save_gif(imgs, a.out, fps=25)
print("wrote", a.out, len(imgs), "frames")

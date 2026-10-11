"""GIF of a trained 3D controller seen from three sides (front, side, three-quarter)."""
import argparse, json
import numpy as np
import viz
from sim3d import Sim3D
from creature3d import build_mjcf
import presets3d

ap = argparse.ArgumentParser(); ap.add_argument("result"); ap.add_argument("--out", required=True)
ap.add_argument("--T", type=float, default=8.0); ap.add_argument("--seconds", type=float, default=5.0)
ap.add_argument("--assist", type=float, default=None); ap.add_argument("--label", default="")
ap.add_argument("--speed", type=float, default=None)
a = ap.parse_args()
j = json.load(open(a.result)); p = np.array(j["params"])
assist = j.get("assist", 0.0) if a.assist is None else a.assist
speed = j.get("speed", 1.0) if a.speed is None else a.speed
s = Sim3D(presets3d.human(presets3d.Body3D(**j["body"])))
r = s.rollout(p, T=a.T, speed=speed, assist=assist, record=True)
print(f"alive {r['alive']:.2f} speed {r['speed']:.2f} lateral {r['lateral']:.2f} f={r['freq']:.2f} Hz assist {assist}")
traj = r["traj"]; n = int(a.seconds / 0.02)
traj = traj[-n:] if r["alive"] >= 1 else traj
views = [("front", 0.0), ("side", 90.0), ("3/4", 45.0)]
cols = []
for name, az in views:
    sc = viz.Scene(build_mjcf(s.c, s.bones), 320, 260)
    fr = []
    for f in traj[::2]:
        q = np.array(f["qpos"])
        img = sc.frame(q, (q[0], q[1]), dist=3.4, azimuth=az + 180, elevation=-8, lookz=0.75)
        fr.append(viz.caption(img, f"{name}  {a.label}", f"{r['speed']:.2f} m/s  {r['freq']:.1f} Hz  harness {assist:.0%}" + ("" if r['alive'] >= 1 else "  FELL")))
    sc.close(); cols.append(fr)
imgs = [viz.grid([c[k] for c in cols], 3) for k in range(min(len(c) for c in cols))]
viz.save_gif(imgs, a.out, fps=25)
print("wrote", a.out, len(imgs), "frames")

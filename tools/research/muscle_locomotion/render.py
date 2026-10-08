"""Replay a trained generalist controller on named bodies: gallery PNG + baked clips.

    python render.py results/biped_general.json [--fr 0.3] [--T 15]
"""
import sys, json, math, argparse
import numpy as np, mujoco
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sim import Sim
import presets

NAMED = {
    "biped": {
        "normal": dict(),
        "dwarf": dict(size=0.65, mass_mult=1.0),
        "tall": dict(size=1.12, mass_mult=0.9),
        "heavy": dict(size=1.0, mass_mult=1.5),
        "armoured": dict(size=1.0, mass_mult=1.1, load=0.2),
        "belly": dict(size=1.0, mass_mult=1.2, belly=0.13),
    },
    "quadruped": {
        "dog": dict(),
        "small": dict(size=0.65),
        "large": dict(size=1.3),
        "loaded": dict(size=1.0, load=0.2),
        "heavy": dict(size=1.0, mass_mult=1.4),
        "belly": dict(size=1.0, belly=0.1),
    },
}

def pose(s, fr):
    m, d = s.model, s.data
    d.qpos[0] = fr["x"]; d.qpos[1] = fr["z"]; d.qpos[2] = fr["pitch"]
    for qa, q in zip(s.jqpos, fr["q"]): d.qpos[qa] = q
    mujoco.mj_forward(m, d)
    segs = []
    for b in s.c.bones:
        g = mujoco.mj_name2id(m, mujoco.mjtObj.mjOBJ_GEOM, "g_" + b.name)
        half = m.geom_size[g][1]; ax = d.geom_xmat[g].reshape(3, 3)[:, 2]
        c = d.geom_xpos[g]
        segs.append((b.name, c - ax * half, c + ax * half, b.foot))
    return segs

def export_clip(s, p, traj, froude, path, fps=30):
    """One stride cycle of joint rotations (radians relative to rest), root motion removed."""
    f = s.frequency(s.unpack(p), np.array([froude] + list(s.c.ctx)))
    period = 1.0 / f; t1 = traj[-1]["t"]; t0 = t1 - period
    T = np.array([fr["t"] for fr in traj]); Q = np.array([fr["q"] for fr in traj]); X = np.array([fr["x"] for fr in traj])
    ts = np.arange(0, period, 1.0 / fps)
    tracks = {b.name: [float(np.interp(t0 + t, T, Q[:, k])) for t in ts] for k, b in enumerate(s.joint_bones)}
    stride = float(np.interp(t1, T, X) - np.interp(t0, T, X))
    clip = dict(creature=s.c.name, body=s.c.body, froude=froude, fps=fps, loop=True, duration=period,
                stride_length_m=stride, speed_mps=stride / period, tracks=tracks, axis="y",
                units="radians_relative_to_rest")
    json.dump(clip, open(path, "w"))
    return clip

if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("result"); ap.add_argument("--fr", type=float, default=None)
    ap.add_argument("--T", type=float, default=15.0)
    a = ap.parse_args()
    j = json.load(open(a.result)); p = np.array(j["params"]); name = j["creature"]
    fr = a.fr if a.fr is not None else 0.5 * (j["fr"][0] + j["fr"][1])
    base = a.result.replace(".json", "")
    bodies = NAMED[name]
    cols = 9
    fig, axes = plt.subplots(len(bodies), cols, figsize=(1.9 * cols, 2.0 * len(bodies)), squeeze=False)
    for ax in axes.ravel(): ax.axis("off")
    for row, (label, kw) in enumerate(bodies.items()):
        body = presets.Body(**kw); s = Sim(getattr(presets, name)(body))
        r = s.rollout(p, T=a.T, froude=fr, record=True)
        traj = r["traj"]
        print(f"{label:9s} size={body.size:.2f} mass={body.mass_mult:.2f} load={body.load:.2f} belly={body.belly:.2f}: "
              f"alive {r['alive']:.2f} speed {r['speed']:.2f} m/s (target {r['v_target']:.2f}) f={r['freq']:.2f} Hz")
        if r["alive"] < 1.0:
            axes[row][0].text(0, 0.5, f"{label}: FELL after {r['alive'] * a.T:.1f} s", fontsize=9, color="red")
            axes[row][0].set_xlim(0, 1); axes[row][0].set_ylim(0, 1); axes[row][0].axis("on"); axes[row][0].set_xticks([]); axes[row][0].set_yticks([])
            continue
        steps = max(8, int(round(1.0 / r["freq"] / 0.02)))
        end = len(traj) - 1
        for col in range(cols):
            i = end - steps + int(col * steps / (cols - 1))
            ax = axes[row][col]
            for nm, A, B, foot in pose(s, traj[i]):
                ax.plot([A[0], B[0]], [A[2], B[2]], lw=2.5, solid_capstyle="round", color="tab:red" if foot else "tab:blue")
            x = traj[i]["x"]; h = max(1.3 * s.stand, 0.5)
            ax.axhline(0, color="k", lw=0.7); ax.set_xlim(x - 0.5 * h, x + 0.5 * h); ax.set_ylim(-0.05, 1.5 * h); ax.set_aspect("equal")
            if col == 0:
                ax.set_title(f"{label} {r['speed']:.2f}m/s", fontsize=7, loc="left")
        if r["alive"] >= 1.0:
            export_clip(s, p, traj, fr, f"{base}_{label}_clip.json")
    fig.tight_layout(); fig.savefig(base + "_gallery.png", dpi=75); plt.close(fig)
    print("wrote", base + "_gallery.png")

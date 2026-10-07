"""Replay an evolved gait: filmstrip PNG + baked animation clip JSON."""
import sys, json, math
import numpy as np, mujoco
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sim import Sim
import presets

def load(path):
    j = json.load(open(path))
    s = Sim(getattr(presets, j["creature"])(**j["kw"]))
    return s, j

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

def strip_grid(s, traj, path, frames, cols=8):
    rows = math.ceil(len(frames) / cols)
    fig, axes = plt.subplots(rows, cols, figsize=(2.1 * cols, 2.2 * rows), squeeze=False)
    for ax in axes.ravel(): ax.axis("off")
    for ax, i in zip(axes.ravel(), frames):
        segs = pose(s, traj[i]); x = traj[i]["x"]
        for name, a, b, foot in segs:
            ax.plot([a[0], b[0]], [a[2], b[2]], lw=3, solid_capstyle="round", color="tab:red" if foot else "tab:blue")
        ax.axhline(0, color="k", lw=0.8); ax.set_xlim(x - 0.8, x + 0.8); ax.set_ylim(-0.05, 1.3); ax.set_aspect("equal")
        ax.set_title(f"t={traj[i]['t']:.2f}", fontsize=7)
    fig.tight_layout(); fig.savefig(path, dpi=80); plt.close(fig)

def export_clip(s, j, traj, path, fps=30):
    """One stride cycle of joint rotations (radians, relative to rest), root motion removed."""
    f = s.unpack(j["params"])[0]; period = 1.0 / f
    t1 = traj[-1]["t"]; t0 = t1 - period
    ts = np.arange(0, period, 1.0 / fps)
    T = np.array([fr["t"] for fr in traj]); Q = np.array([fr["q"] for fr in traj])
    tracks = {b.name: [] for b in s.joint_bones}
    for t in ts:
        for k, b in enumerate(s.joint_bones):
            tracks[b.name].append(float(np.interp(t0 + t, T, Q[:, k])))
    x = np.array([fr["x"] for fr in traj])
    stride = float(np.interp(t1, T, x) - np.interp(t0, T, x))
    clip = dict(creature=s.c.name, fps=fps, loop=True, duration=period, stride_length_m=stride,
                speed_mps=stride / period, tracks=tracks, axis="y", units="radians_relative_to_rest")
    json.dump(clip, open(path, "w"))
    return clip

if __name__ == "__main__":
    path = sys.argv[1]; T = float(sys.argv[2]) if len(sys.argv) > 2 else 8.0
    s, j = load(path)
    r = s.rollout(j["params"], T=T, v_target=j["v_target"], record=True)
    print({k: (round(v, 3) if isinstance(v, float) else v) for k, v in r.items() if k != "traj"})
    traj = r["traj"]
    base = path.replace(".json", "")  # writes <base>_strip.png and <base>_clip.json
    f = r["freq"]; period_steps = max(8, int(round(1.0 / f / 0.02)))
    end = len(traj) - 1
    frames = [end - period_steps + int(k * period_steps / 16) for k in range(17)]
    strip_grid(s, traj, base + "_strip.png", frames, cols=9)
    clip = export_clip(s, j, traj, base + "_clip.json")
    print("clip", round(clip["speed_mps"], 2), "m/s stride", round(clip["stride_length_m"], 2), "m period", round(clip["duration"], 2), "s")

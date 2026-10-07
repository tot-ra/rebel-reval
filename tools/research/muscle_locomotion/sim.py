"""Simulation + micro-network controller for muscle-driven creatures."""
from __future__ import annotations
import math
import numpy as np
import mujoco
from creature import Creature, build_mjcf

CTRL_EVERY = 10          # physics steps per control step (50 Hz at dt=0.002)

class Sim:
    def __init__(self, c: Creature):
        self.c = c
        self.model = mujoco.MjModel.from_xml_string(build_mjcf(c))
        self.data = mujoco.MjData(self.model)
        m = self.model
        self.nm = m.nu
        self.muscle_names = [mujoco.mj_id2name(m, mujoco.mjtObj.mjOBJ_ACTUATOR, i) for i in range(m.nu)]
        self.floor = mujoco.mj_name2id(m, mujoco.mjtObj.mjOBJ_GEOM, "floor")
        self.foot_geoms = [mujoco.mj_name2id(m, mujoco.mjtObj.mjOBJ_GEOM, "g_" + b.name) for b in c.bones if b.foot]
        self.nfoot = len(self.foot_geoms)
        self.joint_bones = [b for b in c.bones[1:]]
        self.jqpos = [m.joint("j_" + b.name).qposadr[0] for b in self.joint_bones]
        self._set_length_ranges()
        self.ns = 2 + self.nfoot
        self.nj = self.nm // 2
        self.nparams = self.nj * (4 + self.ns) + 1

    def _set_length_ranges(self):
        """Each muscle's usable length range = its tendon length swept over the joint's limits."""
        m, d = self.model, self.data
        for i, name in enumerate(self.muscle_names):
            bone = name[2:-2]
            jid = m.joint("j_" + bone).id; qa = m.jnt_qposadr[jid]
            lo, hi = m.jnt_range[jid]
            lens = []
            mujoco.mj_resetData(m, d)
            for q in np.linspace(lo, hi, 25):
                d.qpos[qa] = q
                mujoco.mj_forward(m, d)
                lens.append(d.ten_length[m.actuator_trnid[i, 0]])
            m.actuator_lengthrange[i] = (min(lens), max(lens))
        mujoco.mj_resetData(m, d)

    # --- controller -----------------------------------------------------------
    def unpack(self, p):
        """Per joint: bias a, oscillation amplitude b, phase psi, co-contraction c, sensor weights W.
        The flexor is driven by c+x and the extensor by c-x, so antagonists are structurally paired."""
        nj, ns = self.nj, self.ns
        f = 0.6 + 2.4 / (1 + math.exp(-p[-1]))               # stride frequency 0.6..3.0 Hz
        P = np.asarray(p[:-1]).reshape(nj, 4 + ns)
        return f, P[:, 0], P[:, 1], P[:, 2], P[:, 3], P[:, 4:]

    def drive(self, params, t, s):
        f, a, b, psi, c, W = params
        x = a + b * np.sin(2 * math.pi * f * t + psi) + W @ s
        u = np.empty(self.nm)
        u[0::2] = 1.0 / (1.0 + np.exp(-(c + x)))
        u[1::2] = 1.0 / (1.0 + np.exp(-(c - x)))
        return u

    def sensors(self):
        d = self.data
        pitch = d.qpos[2]; rate = d.qvel[2]
        contacts = np.zeros(self.nfoot)
        for k in range(d.ncon):
            c = d.contact[k]
            for a, b in ((c.geom1, c.geom2), (c.geom2, c.geom1)):
                if a == self.floor and b in self.foot_geoms:
                    contacts[self.foot_geoms.index(b)] = 1.0
        return np.concatenate([[pitch, 0.2 * rate], contacts])

    def _geom_low(self, g):
        m, d = self.model, self.data
        if m.geom_type[g] == 2:
            return d.geom_xpos[g][2] - m.geom_size[g][0]
        half = m.geom_size[g][1]
        axis = d.geom_xmat[g].reshape(3, 3)[:, 2]
        ends = [d.geom_xpos[g] + axis * half, d.geom_xpos[g] - axis * half]
        return min(e[2] for e in ends) - m.geom_size[g][0]

    def fell(self):
        d, c = self.data, self.c
        if c.stand_height + d.qpos[1] < c.fall_height or abs(math.degrees(d.qpos[2])) > c.root_pitch_ok:
            return True
        for k in range(d.ncon):
            g1, g2 = d.contact[k].geom1, d.contact[k].geom2
            other = g2 if g1 == self.floor else g1 if g2 == self.floor else None
            if other is not None and other not in self.foot_geoms:
                return True
        return False

    def rollout(self, p, T=8.0, v_target=1.0, record=False, warm=0.0):
        m, d = self.model, self.data
        mujoco.mj_resetData(m, d)
        mujoco.mj_forward(m, d)
        low = min(self._geom_low(g) for g in self.foot_geoms)
        d.qpos[1] = -low + 0.003
        mujoco.mj_forward(m, d)
        params = self.unpack(p); f = params[0]
        n = int(T / (CTRL_EVERY * m.opt.timestep))
        effort = 0.0; alive = 0; x0 = None; traj = []; verr = 0.0; vcount = 0
        x_prev = d.qpos[0]
        for k in range(n):
            t = k * CTRL_EVERY * m.opt.timestep
            s = self.sensors()
            u = self.drive(params, t, s)
            d.ctrl[:] = u
            for _ in range(CTRL_EVERY):
                mujoco.mj_step(m, d)
            if not np.all(np.isfinite(d.qpos)):
                break
            if self.fell() and t > 0.3:
                break
            alive += 1
            effort += float(np.mean(u * u))
            if t > 1.0:
                vx = (d.qpos[0] - x_prev) / (CTRL_EVERY * m.opt.timestep)
                verr += abs(vx - v_target); vcount += 1
            x_prev = d.qpos[0]
            if record:
                traj.append(dict(t=t, x=float(d.qpos[0]), z=float(d.qpos[1]), pitch=float(d.qpos[2]),
                                 q=[float(d.qpos[i]) for i in self.jqpos], u=[float(v) for v in u],
                                 foot=[float(v) for v in s[2:]]))
        alive_frac = alive / n
        mean_verr = verr / max(vcount, 1) if vcount else v_target + 1.0
        dist = d.qpos[0]
        cost = 10.0 * (1 - alive_frac) + mean_verr + 0.05 * effort / max(alive, 1) * 10
        return dict(cost=cost, alive=alive_frac, dist=float(dist), speed=float(dist / T), verr=mean_verr,
                    freq=f, traj=traj)

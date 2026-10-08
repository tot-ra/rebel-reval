"""3D simulation, symmetric micro-network controller and fitness.

The right side runs the left controller half a cycle later with mirrored sensors, so a
13-degree-of-freedom half body is searched, not the 23 of the whole body.
"""
from __future__ import annotations
import math
import numpy as np
import mujoco
from creature3d import Creature3D, expand, build_mjcf

CTRL_EVERY = 10
G = 9.81
NSENS = 11        # gravity(3) angular velocity(3) velocity(3) foot contacts(2), all in the pelvis frame
MIRROR_G = np.array([1, -1, 1.0]); MIRROR_W = np.array([-1, 1, -1.0]); MIRROR_V = np.array([1, -1, 1.0])

class Sim3D:
    def __init__(self, c: Creature3D):
        self.c = c
        self.bones = expand(c)
        self.model = mujoco.MjModel.from_xml_string(build_mjcf(c, self.bones))
        self.data = mujoco.MjData(self.model)
        m = self.model
        self.floor = mujoco.mj_name2id(m, mujoco.mjtObj.mjOBJ_GEOM, "floor")
        self.root = m.body(self.bones[0].name).id
        self.foot_geoms = [m.geom("g_foot_L").id, m.geom("g_foot_R").id]
        self.total_mass = float(m.body_mass.sum())
        # degrees of freedom in model order; right side maps to its left twin
        self.dofs = []          # (bone name, k, joint qpos address)
        for b in self.bones:
            for k in range(len(b.dofs)):
                self.dofs.append((b.name, k, int(m.joint(f"j_{b.name}_{k}").qposadr[0])))
        self.pidx = []; self.shift = []; self.right = []
        left_index = {}
        for n, (name, k, qa) in enumerate(self.dofs):
            if name.endswith("_R"):
                self.pidx.append(left_index[(name[:-2] + "_L", k)]); self.shift.append(math.pi); self.right.append(True)
            else:
                left_index[(name, k)] = len(left_index); self.pidx.append(left_index[(name, k)]); self.shift.append(0.0); self.right.append(False)
        self.right = np.array(self.right); self.shift = np.array(self.shift); self.pidx = np.array(self.pidx)
        self.npd = len(left_index)
        self.per = 4 + NSENS
        self.nparams = self.npd * self.per + 1
        # muscle length ranges follow the joint ranges (fixed tendons: length = coef * angle)
        self._set_length_ranges()
        mujoco.mj_resetData(m, self.data); mujoco.mj_forward(m, self.data)
        self.low = min(self._geom_low(g) for g in self.foot_geoms)
        self.stand = c.stand_height - self.low + 0.003

    def _set_length_ranges(self):
        m = self.model
        by = {b.name: b for b in self.bones}
        for i in range(m.nu):
            name = mujoco.mj_id2name(m, mujoco.mjtObj.mjOBJ_ACTUATOR, i)
            body, k, tag = name[2:].rsplit("_", 2)
            jid = m.joint(f"j_{body}_{k}").id
            lo, hi = m.jnt_range[jid]          # radians inside the compiled model
            arm = by[body].dofs[int(k)].arm
            a, b = (arm * lo, arm * hi) if tag == "a" else (-arm * hi, -arm * lo)
            m.actuator_lengthrange[i] = (min(a, b), max(a, b))

    def _geom_low(self, g):
        m, d = self.model, self.data
        R = d.geom_xmat[g].reshape(3, 3)
        if m.geom_type[g] == mujoco.mjtGeom.mjGEOM_BOX:
            return d.geom_xpos[g][2] - float(np.abs(R[2]) @ m.geom_size[g])
        if m.geom_type[g] == mujoco.mjtGeom.mjGEOM_SPHERE:
            return d.geom_xpos[g][2] - m.geom_size[g][0]
        half = m.geom_size[g][1]
        ax = R[:, 2]
        return min((d.geom_xpos[g] + ax * half)[2], (d.geom_xpos[g] - ax * half)[2]) - m.geom_size[g][0]

    # --- sensors and controller ---------------------------------------------------
    def sensors(self):
        d = self.data
        R = d.xmat[self.root].reshape(3, 3)
        g = R.T @ np.array([0, 0, -1.0]); w = d.qvel[3:6].copy(); v = R.T @ d.qvel[0:3]
        con = np.zeros(2)
        for k in range(d.ncon):
            c = d.contact[k]
            for a, b in ((c.geom1, c.geom2), (c.geom2, c.geom1)):
                if a == self.floor and b in self.foot_geoms:
                    con[self.foot_geoms.index(b)] = 1.0
        self.last_contacts = con
        left = np.concatenate([g, 0.2 * w, 0.5 * v / math.sqrt(self.stand), con])
        right = np.concatenate([g * MIRROR_G, 0.2 * w * MIRROR_W, 0.5 * v * MIRROR_V / math.sqrt(self.stand), con[::-1]])
        return left, right

    def unpack(self, p):
        P = np.asarray(p[:-1]).reshape(self.npd, self.per)
        return dict(a=P[:, 0], b=P[:, 1], psi=P[:, 2], c=P[:, 3], W=P[:, 4:], f0=p[-1])

    def frequency(self, q):
        lo, hi = 0.6, 2.2
        return (lo + (hi - lo) / (1 + math.exp(-q["f0"]))) / math.sqrt(self.c.body.get("size", 1.0))

    def drive(self, q, f, t, s_left, s_right):
        """u[2i] flexor, u[2i+1] extensor for every degree of freedom i (model order)."""
        idx = self.pidx
        fb = np.empty(len(idx))
        W = q["W"][idx]
        fb[~self.right] = (W[~self.right] @ s_left)
        fb[self.right] = (W[self.right] @ s_right)
        x = q["a"][idx] + q["b"][idx] * np.sin(2 * math.pi * f * t + q["psi"][idx] + self.shift) + fb
        cc = q["c"][idx]
        u = np.empty(2 * len(idx))
        u[0::2] = 1.0 / (1.0 + np.exp(-(cc + x)))
        u[1::2] = 1.0 / (1.0 + np.exp(-(cc - x)))
        return u

    # --- episode ------------------------------------------------------------------
    def fell(self):
        d, c = self.data, self.c
        R = d.xmat[self.root].reshape(3, 3)
        if d.qpos[2] < c.fall_frac * self.stand or math.degrees(math.acos(max(-1, min(1, R[2, 2])))) > c.max_tilt_deg:
            return True
        for k in range(d.ncon):
            g1, g2 = d.contact[k].geom1, d.contact[k].geom2
            other = g2 if g1 == self.floor else g1 if g2 == self.floor else None
            if other is not None and other not in self.foot_geoms:
                return True
        return False

    def _assist(self, level):
        """Harness: carries part of the weight and keeps the pelvis upright. Annealed to zero in training."""
        d = self.data
        R = d.xmat[self.root].reshape(3, 3)
        z, vz = d.qpos[2], d.qvel[2]
        Fz = level * (0.9 * self.total_mass * G + 3000.0 * (self.stand - z) - 300.0 * vz)
        e = np.cross(R[:, 2], np.array([0, 0, 1.0])); w_world = R @ d.qvel[3:6]
        tq = level * (800.0 * e - 80.0 * w_world)
        d.xfrc_applied[self.root] = [0, 0, Fz, tq[0], tq[1], 0]

    def rollout(self, p, T=8.0, speed=1.0, assist=0.0, record=False, push=None, w_speed=2.0):
        m, d = self.model, self.data
        mujoco.mj_resetData(m, d); mujoco.mj_forward(m, d)
        d.qpos[2] = self.c.stand_height - self.low + 0.003
        mujoco.mj_forward(m, d)
        q = self.unpack(p); f = self.frequency(q)
        n = int(T / (CTRL_EVERY * m.opt.timestep))
        d.qvel[0] = 0.6 * speed
        effort = tilt = sag = yaw_err = 0.0; air = np.zeros(2); alive = 0; traj = []; verr = 0.0; vcount = 0
        pushed = push is None
        for k in range(n):
            t = k * CTRL_EVERY * m.opt.timestep
            if not pushed and t >= push[0]:
                d.qvel[0:3] += np.array(push[1]) / self.total_mass; pushed = True
            sl, sr = self.sensors()
            u = self.drive(q, f, t, sl, sr)
            d.ctrl[:] = u
            for _ in range(CTRL_EVERY):
                if assist > 0:
                    self._assist(assist)
                mujoco.mj_step(m, d)
            if not np.all(np.isfinite(d.qpos)):
                break
            if self.fell() and t > 0.3:
                break
            alive += 1
            R = d.xmat[self.root].reshape(3, 3)
            effort += float(np.mean(u * u)); tilt += math.acos(max(-1, min(1, R[2, 2])))
            sag += max(0.0, 0.85 - d.qpos[2] / self.stand)
            yaw_err += abs(math.atan2(R[1, 0], R[0, 0]))
            air += 1.0 - self.last_contacts
            if t > 1.0:
                vcount += 1; verr += abs(d.qvel[0] - speed) / max(speed, 0.2)
            if record:
                traj.append(dict(t=t, qpos=d.qpos.copy().tolist()))
        na = max(alive, 1); alive_frac = alive / n
        mean_verr = verr / max(vcount, 1) if vcount else 2.0
        lateral = abs(d.qpos[1]) / max(T * speed, 1.0)
        cost = (10.0 * (1 - alive_frac) + w_speed * mean_verr + 0.5 * effort / na + 10.0 * sag / na + 2.0 * tilt / na
                + 0.5 * yaw_err / na + 2.0 * lateral + 2.0 * float(np.mean(np.abs(air / na - 0.38))))
        return dict(cost=cost, alive=alive_frac, dist=float(d.qpos[0]), lateral=float(d.qpos[1]), speed=float(d.qpos[0] / T),
                    verr=mean_verr, freq=f, traj=traj)

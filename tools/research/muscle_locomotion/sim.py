"""Simulation, micro-network controller and fitness for muscle-driven creatures.

One controller can serve many bodies: it sees a context vector (Froude number of the
target speed plus the body parameters), so a single set of weights covers a range of
sizes, masses, strengths and loads.
"""
from __future__ import annotations
import math
import numpy as np
import mujoco
from creature import Creature, build_mjcf

CTRL_EVERY = 10          # physics steps per control step (50 Hz at dt=0.002)
G = 9.81
W_SPEED = 1.0            # weight of the speed-tracking term (set by the trainer)
NCTX = 6                 # [froude, log size, log mass_mult, log strength, load, belly]

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
        self.joint_bones = list(c.bones[1:])
        self.jqpos = [m.joint("j_" + b.name).qposadr[0] for b in self.joint_bones]
        self._set_length_ranges()
        mujoco.mj_resetData(m, self.data); mujoco.mj_forward(m, self.data)
        self.low = min(self._geom_low(g) for g in self.foot_geoms)
        self.stand = c.stand_height - self.low + 0.003          # root height when standing
        self.body_ctx = list(c.body_ctx) if hasattr(c, "body_ctx") else None
        self.ns = 2 + self.nfoot + (2 + len(self.joint_bones) if c.proprio else 0) + NCTX
        self.nj = self.nm // 2
        self.per_joint = 4 + self.ns + 3 * NCTX
        self.nparams = self.nj * self.per_joint + 1 + NCTX

    def _set_length_ranges(self):
        """Each muscle's usable length range = its tendon length swept over the joint's limits."""
        m, d = self.model, self.data
        for i, name in enumerate(self.muscle_names):
            jid = m.joint("j_" + name[2:-2]).id; qa = m.jnt_qposadr[jid]
            lo, hi = m.jnt_range[jid]
            lens = []
            mujoco.mj_resetData(m, d)
            for q in np.linspace(lo, hi, 25):
                d.qpos[qa] = q
                mujoco.mj_forward(m, d)
                lens.append(d.ten_length[m.actuator_trnid[i, 0]])
            m.actuator_lengthrange[i] = (min(lens), max(lens))
        mujoco.mj_resetData(m, d)

    def _geom_low(self, g):
        m, d = self.model, self.data
        if m.geom_type[g] == 2:
            return d.geom_xpos[g][2] - m.geom_size[g][0]
        half = m.geom_size[g][1]
        axis = d.geom_xmat[g].reshape(3, 3)[:, 2]
        ends = [d.geom_xpos[g] + axis * half, d.geom_xpos[g] - axis * half]
        return min(e[2] for e in ends) - m.geom_size[g][0]

    # --- controller -----------------------------------------------------------
    def unpack(self, p):
        """Per joint: bias a, amplitude b, phase psi, co-contraction c, sensor weights W, and
        context modulators of a, b and c. Flexor is driven by c+x, extensor by c-x."""
        nj, pj = self.nj, self.per_joint
        P = np.asarray(p[:-1 - NCTX]).reshape(nj, pj)
        ns = self.ns
        q = dict(a=P[:, 0], b=P[:, 1], psi=P[:, 2], c=P[:, 3], W=P[:, 4:4 + ns],
                 Ma=P[:, 4 + ns:4 + ns + NCTX], Mb=P[:, 4 + ns + NCTX:4 + ns + 2 * NCTX],
                 Mc=P[:, 4 + ns + 2 * NCTX:4 + ns + 3 * NCTX],
                 f0=p[-1 - NCTX], fc=np.asarray(p[-NCTX:]))
        return q

    def frequency(self, q, ctx):
        lo, hi = self.c.f_range
        size = self.c.body.get("size", 1.0) if self.c.body else 1.0
        return (lo + (hi - lo) / (1 + math.exp(-(q["f0"] + float(q["fc"] @ ctx))))) / math.sqrt(size)

    def drive(self, q, f, t, s, ctx):
        x = q["a"] + q["Ma"] @ ctx + (q["b"] + q["Mb"] @ ctx) * np.sin(2 * math.pi * f * t + q["psi"]) + q["W"] @ s
        c = q["c"] + q["Mc"] @ ctx
        u = np.empty(self.nm)
        u[0::2] = 1.0 / (1.0 + np.exp(-(c + x)))
        u[1::2] = 1.0 / (1.0 + np.exp(-(c - x)))
        return u

    def sensors(self, ctx):
        d = self.data
        pitch = d.qpos[2]; rate = d.qvel[2]
        contacts = np.zeros(self.nfoot)
        for k in range(d.ncon):
            c = d.contact[k]
            for a, b in ((c.geom1, c.geom2), (c.geom2, c.geom1)):
                if a == self.floor and b in self.foot_geoms:
                    contacts[self.foot_geoms.index(b)] = 1.0
        self.last_contacts = contacts
        base = [pitch, 0.2 * rate]
        if self.c.proprio:
            base += [0.5 * d.qvel[0] / math.sqrt(self.stand), (d.qpos[1] + self.c.stand_height) / self.stand - 1.0]
            base += [d.qpos[i] for i in self.jqpos]
        return np.concatenate([base, contacts, ctx])

    def fell(self):
        d, c = self.data, self.c
        if c.stand_height + d.qpos[1] < c.fall_frac * self.stand or abs(math.degrees(d.qpos[2])) > c.root_pitch_ok:
            return True
        for k in range(d.ncon):
            g1, g2 = d.contact[k].geom1, d.contact[k].geom2
            other = g2 if g1 == self.floor else g1 if g2 == self.floor else None
            if other is not None and other not in self.foot_geoms:
                return True
        return False

    def rollout(self, p, T=8.0, froude=0.33, record=False, push=None):
        """Walk at Froude number `froude` (speed = froude * sqrt(g * standing height)).
        `push` = (time_s, impulse_Ns) applies a horizontal shove on the trunk."""
        m, d = self.model, self.data
        mujoco.mj_resetData(m, d)
        mujoco.mj_forward(m, d)
        d.qpos[1] = -self.low + 0.003
        mujoco.mj_forward(m, d)
        v_target = froude * math.sqrt(G * self.stand)
        ctx = np.array([froude] + list(self.c.ctx))
        q = self.unpack(p); f = self.frequency(q, ctx)
        n = int(T / (CTRL_EVERY * m.opt.timestep))
        d.qvel[0] = self.c.start_speed * v_target
        effort = sag = tilt = 0.0; air = np.zeros(self.nfoot); alive = 0; traj = []; verr = 0.0; vcount = 0
        x_prev = d.qpos[0]; pushed = push is None
        root_body = m.body(self.c.bones[0].name).id
        for k in range(n):
            t = k * CTRL_EVERY * m.opt.timestep
            if not pushed and t >= push[0]:
                d.qvel[0] += push[1] / m.body_subtreemass[root_body]
                pushed = True
            sens = self.sensors(ctx)
            u = self.drive(q, f, t, sens, ctx)
            d.ctrl[:] = u
            for _ in range(CTRL_EVERY):
                mujoco.mj_step(m, d)
            if not np.all(np.isfinite(d.qpos)):
                break
            if self.fell() and t > 0.3:
                break
            alive += 1
            air += 1.0 - self.last_contacts
            effort += float(np.mean(u * u))
            zr = (d.qpos[1] + self.c.stand_height) / self.stand
            sag += max(0.0, 0.85 - zr); tilt += abs(d.qpos[2])
            if t > 1.0:
                vx = (d.qpos[0] - x_prev) / (CTRL_EVERY * m.opt.timestep)
                verr += abs(vx - v_target) / max(v_target, 0.2); vcount += 1
            x_prev = d.qpos[0]
            if record:
                traj.append(dict(t=t, x=float(d.qpos[0]), z=float(d.qpos[1]), pitch=float(d.qpos[2]),
                                 q=[float(d.qpos[i]) for i in self.jqpos]))
        alive_frac = alive / n
        mean_verr = verr / max(vcount, 1) if vcount else 2.0
        na = max(alive, 1)
        gait = self.c.w_air * float(np.mean(np.abs(air / na - self.c.air_target)))
        cost = (10.0 * (1 - alive_frac) + W_SPEED * mean_verr + self.c.w_effort * effort / na
                + self.c.w_height * sag / na * 10 + self.c.w_pitch * tilt / na + gait)
        return dict(cost=cost, alive=alive_frac, dist=float(d.qpos[0]), speed=float(d.qpos[0] / T), verr=mean_verr,
                    freq=f, v_target=v_target, traj=traj)

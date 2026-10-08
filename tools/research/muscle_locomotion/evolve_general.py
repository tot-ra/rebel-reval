"""Evolve ONE controller for a whole range of bodies and speeds.

Each generation every candidate is scored on the same few (body, speed) scenarios drawn from
the training distribution, so noise is shared and the search is fair. At the end the best
controller is tested on all training bodies and on held-out bodies it never saw.
"""
import argparse, json, time, math
import numpy as np, cma
from multiprocessing import Pool
from dataclasses import asdict
from sim import Sim
import presets

RANGES = {   # name -> {param: (low, high)}
    "human_narrow": dict(size=(0.9, 1.1), mass_mult=(0.9, 1.2), strength=(0.95, 1.05), load=(0.0, 0.1), belly=(0.0, 0.0)),
    "human_wide":   dict(size=(0.6, 1.15), mass_mult=(0.8, 1.6), strength=(0.8, 1.2), load=(0.0, 0.25), belly=(0.0, 0.15)),
    "dog_narrow":   dict(size=(0.9, 1.1), mass_mult=(0.9, 1.2), strength=(0.95, 1.05), load=(0.0, 0.1), belly=(0.0, 0.0)),
    "dog_wide":     dict(size=(0.6, 1.4), mass_mult=(0.8, 1.4), strength=(0.85, 1.15), load=(0.0, 0.25), belly=(0.0, 0.1)),
}
_CACHE = {}
_CACHE_MAX = 60

def make_body(rng, rname, corners=True):
    """Random body from the range. With `corners`, each parameter is often pinned to its low or high
    bound, so the extremes (no load, no belly, smallest, heaviest) are always trained, not just the middle."""
    r = RANGES[rname]
    vals = {}
    for k, (lo, hi) in r.items():
        u = rng.random()
        vals[k] = lo if corners and u < 0.25 else hi if corners and u < 0.35 else float(rng.uniform(lo, hi))
    return presets.Body(**vals)

def _sim(creature, body):
    key = (creature, tuple(sorted(asdict(body).items())))
    if key not in _CACHE:
        if len(_CACHE) > _CACHE_MAX:
            _CACHE.clear()
        _CACHE[key] = Sim(getattr(presets, creature)(body))
    return _CACHE[key]

def _eval(args):
    creature, p, scen, T = args
    costs = []
    for body, fr in scen:
        costs.append(_sim(creature, body).rollout(p, T=T, froude=fr)["cost"])
    return float(np.mean(costs))

def report(creature, p, bodies, frs, T, label):
    print(f"--- {label}")
    ok = 0; n = 0
    for body in bodies:
        s = _sim(creature, body)
        row = []
        for fr in frs:
            r = s.rollout(p, T=T, froude=fr)
            n += 1; ok += r["alive"] >= 1.0
            row.append(f"Fr{fr:.2f}:{'ok ' if r['alive']>=1 else 'FALL'} v={r['speed']:.2f}/{r['v_target']:.2f}")
        print(f" size={body.size:.2f} mass={body.mass_mult:.2f} str={body.strength:.2f} load={body.load:.2f} belly={body.belly:.2f} | " + " | ".join(row))
    print(f" survived {ok}/{n}")
    return ok, n

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("creature"); ap.add_argument("--ranges", required=True)
    ap.add_argument("--fr", type=float, nargs=2, default=[0.25, 0.45])
    ap.add_argument("--gens", type=int, default=300); ap.add_argument("--pop", type=int, default=48)
    ap.add_argument("--T", type=float, default=10.0); ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--seed", type=int, default=1); ap.add_argument("--sigma", type=float, default=0.6)
    ap.add_argument("--init"); ap.add_argument("--out", required=True); ap.add_argument("--w-speed", type=float, default=1.0)
    a = ap.parse_args()
    import sim as _sim_mod; _sim_mod.W_SPEED = a.w_speed
    rng = np.random.default_rng(a.seed)
    train = [make_body(rng, a.ranges) for _ in range(10)]
    test = [make_body(np.random.default_rng(1000 + i), a.ranges) for i in range(10)]
    nominal = presets.Body()
    s0 = _sim(a.creature, presets.Body())
    if a.init:
        x0 = np.array(json.load(open(a.init))["params"])
    else:
        x0 = np.zeros(s0.nparams)
        P = x0[:-1 - 6].reshape(s0.npj, s0.per_joint)
        P[:, 1] = 2.0; P[:, 2] = rng.uniform(0, 2 * np.pi, s0.npj); P[:, 3] = 0.5
        x0 = np.concatenate([P.ravel(), np.zeros(1 + 6)]) + rng.normal(0, 0.05, s0.nparams)
    es = cma.CMAEvolutionStrategy(x0, a.sigma, {"popsize": a.pop, "seed": a.seed, "verbose": -9})
    best = (1e9, x0); t0 = time.time()
    with Pool(4) as pool:
        for g in range(a.gens):
            gr = np.random.default_rng(a.seed * 100003 + g)
            scen = [(make_body(gr, a.ranges), float(gr.uniform(*a.fr))) for _ in range(a.k)]
            if g % 4 == 0:
                scen[0] = (nominal, scen[0][1])      # the plain body is always part of the mix
            X = es.ask()
            f = pool.map(_eval, [(a.creature, x, scen, a.T) for x in X])
            es.tell(X, f)
            i = int(np.argmin(f))
            if g % 20 == 0 or g == a.gens - 1:
                print(f"gen {g:4d} mean-best {min(f):.3f} median {np.median(f):.3f} [{time.time()-t0:.0f}s]", flush=True)
            if g == a.gens - 1 or g % 20 == 0:
                best = (f[i], np.array(X[i]))
        # the CMA mean is usually the most robust; use it as the result
        p = np.array(es.result.xfavorite)
    frs = [a.fr[0], 0.5 * (a.fr[0] + a.fr[1]), a.fr[1]]
    json.dump(dict(creature=a.creature, ranges=a.ranges, fr=a.fr, params=p.tolist()), open(a.out, "w"))
    report(a.creature, p, [nominal] + train[:4], frs, 15.0, "nominal and sampled bodies (15 s test)")
    report(a.creature, p, test, frs, 15.0, "held-out bodies (never seen)")

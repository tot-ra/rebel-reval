"""CMA-ES search for the micro-network that makes a creature walk."""
import sys, json, time, argparse
import numpy as np, cma
from multiprocessing import Pool
from sim import Sim
import presets

_S = None
def _init(name, kw):
    global _S
    _S = Sim(getattr(presets, name)(**kw))
def _eval(args):
    p, T, vt = args
    return _S.rollout(p, T=T, v_target=vt)["cost"]

def run(name, kw, gens, pop, T, vt, seed, out, sigma=0.8, init=None):
    s = Sim(getattr(presets, name)(**kw))
    x0 = np.zeros(s.nparams) if init is None else np.array(init)
    if init is None:
        rng = np.random.default_rng(seed)
        P = x0[:-1].reshape(s.nj, 4 + s.ns)
        P[:, 1] = 2.0                                  # start with strong oscillation
        P[:, 2] = rng.uniform(0, 2 * np.pi, s.nj)       # random phases
        P[:, 3] = 0.5                                  # some co-contraction (stiffness)
        x0 = np.concatenate([P.ravel(), [0.0]]) + rng.normal(0, 0.1, s.nparams)
    es = cma.CMAEvolutionStrategy(x0, sigma, {"popsize": pop, "seed": seed, "verbose": -9})
    best = (1e9, None); t0 = time.time()
    with Pool(4, initializer=_init, initargs=(name, kw)) as pool:
        for g in range(gens):
            X = es.ask()
            f = pool.map(_eval, [(x, T, vt) for x in X])
            es.tell(X, f)
            i = int(np.argmin(f))
            if f[i] < best[0]: best = (f[i], np.array(X[i]))
            if g % 10 == 0 or g == gens - 1:
                r = s.rollout(best[1], T=T, v_target=vt)
                print(f"gen {g:3d} best {best[0]:.3f} alive {r['alive']:.2f} speed {r['speed']:.2f} f={r['freq']:.2f}Hz  [{time.time()-t0:.0f}s]", flush=True)
    json.dump(dict(creature=name, kw=kw, v_target=vt, T=T, cost=best[0], params=best[1].tolist()), open(out, "w"))
    return best

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("creature"); ap.add_argument("--gens", type=int, default=100)
    ap.add_argument("--pop", type=int, default=24); ap.add_argument("--T", type=float, default=8.0)
    ap.add_argument("--v", type=float, default=1.0); ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--belly", type=float, default=0.0); ap.add_argument("--out", default=None)
    ap.add_argument("--init", default=None)
    a = ap.parse_args()
    kw = {"belly": a.belly} if a.belly else {}
    init = json.load(open(a.init))["params"] if a.init else None
    run(a.creature, kw, a.gens, a.pop, a.T, a.v, a.seed, a.out or f"best_{a.creature}.json", init=init)

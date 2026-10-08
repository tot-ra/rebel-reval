"""CMA-ES for the 3D controller with an assist curriculum (harness annealed to zero)."""
import argparse, json, time
import numpy as np, cma
from multiprocessing import Pool
from sim3d import Sim3D
import presets3d

_S = {}
def _sim(body):
    key = tuple(sorted(body.items()))
    if key not in _S:
        _S[key] = Sim3D(presets3d.human(presets3d.Body3D(**body)))
    return _S[key]

def _eval(a):
    body, p, T, speed, assist = a
    return _sim(body).rollout(p, T=T, speed=speed, assist=assist)["cost"]

def run(body, stages, pop, T, speed, seed, init, out_prefix):
    s0 = _sim(body)
    rng = np.random.default_rng(seed)
    if init:
        x = np.array(json.load(open(init))["params"])
    else:
        x = np.zeros(s0.nparams)
        P = x[:-1].reshape(s0.npd, s0.per)
        P[:, 1] = 1.5; P[:, 2] = rng.uniform(0, 2 * np.pi, s0.npd); P[:, 3] = 0.5
        x = x + rng.normal(0, 0.05, s0.nparams)
    with Pool(4) as pool:
        for si, (assist, gens) in enumerate(stages):
            es = cma.CMAEvolutionStrategy(x, 0.5 if si == 0 else 0.3, {"popsize": pop, "seed": seed + si, "verbose": -9})
            t0 = time.time()
            for g in range(gens):
                X = es.ask()
                f = pool.map(_eval, [(body, xi, T, speed, assist) for xi in X])
                es.tell(X, f)
                if g % 25 == 0:
                    json.dump(dict(body=body, speed=speed, assist=assist, gen=g, params=list(map(float, es.result.xfavorite))), open(f"{out_prefix}_a{assist:.2f}.partial", "w"))
                if g % 25 == 0 or g == gens - 1:
                    r = s0.rollout(np.array(es.result.xfavorite), T=T, speed=speed, assist=assist)
                    print(f"assist {assist:.2f} gen {g:4d} best {min(f):.3f} | mean-solution alive {r['alive']:.2f} speed {r['speed']:.2f} lat {r['lateral']:.2f} [{time.time()-t0:.0f}s]", flush=True)
            x = np.array(es.result.xfavorite)
            json.dump(dict(body=body, speed=speed, assist=assist, params=x.tolist()), open(f"{out_prefix}_a{assist:.2f}.json", "w"))
    return x

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--stages", default="1.0:150,0.7:150,0.45:150,0.25:150,0.1:150,0.0:400")
    ap.add_argument("--pop", type=int, default=64); ap.add_argument("--T", type=float, default=8.0)
    ap.add_argument("--speed", type=float, default=1.0); ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--init"); ap.add_argument("--out", required=True)
    a = ap.parse_args()
    stages = [(float(x.split(":")[0]), int(x.split(":")[1])) for x in a.stages.split(",")]
    run(presets3d.asdict(presets3d.Body3D()), stages, a.pop, a.T, a.speed, a.seed, a.init, a.out)

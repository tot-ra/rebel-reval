"""Generate original frontal face portraits for realistic humans (ADR 0022).

Build-time only. Uses the local ComfyUI server with FLUX.2 [klein] 4B
(Apache-2.0) and the Qwen3-4B text encoder. Each portrait is a strict
frontal, evenly lit studio photograph described from the character's spec, so
`surfaces.project_face_photo` can project its skin detail onto the face.

    python3 tools/assets/realistic_humans/generate_portraits.py mart henning ...

Writes assets/characters/realistic/<name>/reference/portrait.png (excluded
from Godot import) plus portrait.json (prompt, seed, model). Facial landmarks
(eye/nose/mouth pixels) are then recorded in the spec's `face_photo`.
"""
from pathlib import Path
import json
import sys
import time
import urllib.request

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import specs  # noqa: E402

SERVER = "http://127.0.0.1:8188"
# The fp8 release cannot run on Apple MPS; a local bf16 dequantization of it is used.
MODEL = "flux-2-klein-4b-bf16-dequant.safetensors"
TEXT_ENCODER = "qwen_3_4b.safetensors"
VAE = "flux2-vae.safetensors"
WIDTH, HEIGHT = 1024, 1536
STEPS = 4
OUTPUT = Path.home() / "ComfyUI-Shared" / "output"

HAIR_WORDS = [((0.55, 0.5, 0.45), "grey"), ((0.5, 0.42, 0.28), "dark blond"), ((0.62, 0.53, 0.36), "flaxen blond"),
              ((0.46, 0.25, 0.15), "auburn"), ((0.34, 0.25, 0.17), "brown"), ((0.24, 0.18, 0.13), "dark brown"),
              ((0.12, 0.10, 0.09), "black")]


# Spec shape targets -> words, so each portrait matches its own head sculpt
# and no two characters share a face.
FEATURE_WORDS = {
    "head-square": "square jaw", "head-round": "round face", "head-oval": "oval face",
    "head-fat-incr": "fleshy full face", "neck-double-incr": "double chin",
    "nose-hump-incr": "aquiline nose with a bump", "nose-volume-incr": "broad fleshy nose",
    "nose-scale-horiz-decr": "narrow straight nose", "nose-point-width-incr": "wide nose tip",
    "cheek-bones-incr": "high cheekbones", "cheek-inner-incr": "gaunt hollow cheeks",
    "cheek-volume-incr": "full rounded cheeks", "chin-prominent-incr": "strong prominent chin",
    "chin-width-incr": "broad chin", "eyebrows-trans-down": "heavy low brows",
    "mouth-angles-down": "downturned mouth corners", "head-age-decr": "soft youthful features",
}
EYE_WORDS = {"lightblue": "pale blue", "bluegreen": "blue-green", "deepblue": "deep blue", "brownlight": "hazel"}


def hair_word(color):
    return min(HAIR_WORDS, key=lambda hw: sum((a - b) ** 2 for a, b in zip(hw[0], color)))[1]


def prompt_for(name, spec):
    m = spec["macros"]
    male = m["gender"] > 0.5
    age = round(1 + (m["age"] - 0.1875) * 24 / 0.3125) if m["age"] <= 0.5 else round(25 + (m["age"] - 0.5) * 130)
    build = "heavy-set" if m["weight"] > 0.72 else "lean" if m["weight"] < 0.45 else "sturdy"
    hair = hair_word(spec.get("hair_color", (0.3, 0.22, 0.15))) if spec.get("hair") else "shaved"
    if spec.get("hair") and age >= 45:
        hair = "greying " + hair
    who = ("teenage boy with a youthful beardless face" if male else "teenage girl") if age < 19 else \
        ("man" if male else "woman")
    parts = [f"Frontal passport photograph of a {age}-year-old {build} Northern European "
             f"{who} from fourteenth-century Estonia,",
             "head and upper shoulders, perfectly front-facing, eyes looking straight into the camera,",
             "neutral relaxed expression, mouth closed, ears visible, symmetrical framing, face centred,",
             f"{hair} hair pulled back away from the forehead and ears,"]
    features = [w for t, w in FEATURE_WORDS.items() if spec["targets"].get(t, 0) >= 0.25]
    if features:
        parts.append(", ".join(features) + ",")
    parts.append(f"{EYE_WORDS.get(spec['eyes'], spec['eyes'])} eyes,")
    if spec.get("beard"):
        parts.append(f"{'grizzled ' if spec['beard'].get('grey', 0) > 0.3 else ''}short full beard and moustache,")
    elif male:
        parts.append("clean-shaven with light stubble,")
    parts += ["weathered sun-tanned skin with visible pores, freckles and fine wrinkles, no make-up,"
              if spec.get("complexion", {}).get("tan", 0.3) > 0.35 else
              "natural skin with visible pores and fine detail, no make-up,",
              "bare neck, no hat, no jewellery,",
              "flat even soft studio lighting, plain neutral grey background, sharp focus, photorealistic."]
    return " ".join(parts)


def workflow(prompt, seed, prefix):
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": MODEL, "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": TEXT_ENCODER, "type": "flux2"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["2", 0]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"text": "", "clip": ["2", 0]}},
        "6": {"class_type": "EmptyFlux2LatentImage", "inputs": {"width": WIDTH, "height": HEIGHT, "batch_size": 1}},
        "7": {"class_type": "Flux2Scheduler", "inputs": {"steps": STEPS, "width": WIDTH, "height": HEIGHT}},
        "8": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "euler"}},
        "9": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "10": {"class_type": "CFGGuider", "inputs": {"model": ["1", 0], "positive": ["4", 0], "negative": ["5", 0], "cfg": 1.0}},
        "11": {"class_type": "SamplerCustomAdvanced", "inputs": {"noise": ["9", 0], "guider": ["10", 0],
                                                                "sampler": ["8", 0], "sigmas": ["7", 0],
                                                                "latent_image": ["6", 0]}},
        "12": {"class_type": "VAEDecode", "inputs": {"samples": ["11", 0], "vae": ["3", 0]}},
        "13": {"class_type": "SaveImage", "inputs": {"images": ["12", 0], "filename_prefix": prefix}},
    }


def run(name, seed=None):
    # Distinct, stable seed per character (a shared seed made one face for all).
    seed = seed if seed is not None else 1343 + sum(ord(c) * 131 ** i for i, c in enumerate(name)) % 100000
    spec = specs.SPECS[name]
    prompt = prompt_for(name, spec)
    prefix = f"rr_portrait_{name}"
    body = json.dumps({"prompt": workflow(prompt, seed, prefix)}).encode()
    request = urllib.request.Request(f"{SERVER}/prompt", data=body, headers={"Content-Type": "application/json"})
    prompt_id = json.loads(urllib.request.urlopen(request).read())["prompt_id"]
    for _ in range(600):
        history = json.loads(urllib.request.urlopen(f"{SERVER}/history/{prompt_id}").read())
        if prompt_id in history:
            break
        time.sleep(2)
    outputs = history[prompt_id]["outputs"]["13"]["images"][0]
    source = OUTPUT / outputs.get("subfolder", "") / outputs["filename"]
    target = ROOT / f"assets/characters/realistic/{name}/reference/portrait.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    (target.parent / ".gdignore").touch()
    target.write_bytes(source.read_bytes())
    (target.parent / "portrait.json").write_text(json.dumps(
        {"model": MODEL, "text_encoder": TEXT_ENCODER, "license": "Apache-2.0 (FLUX.2 klein 4B)",
         "seed": seed, "steps": STEPS, "size": [WIDTH, HEIGHT], "prompt": prompt}, indent=2) + "\n")
    print("wrote", target.relative_to(ROOT))


if __name__ == "__main__":
    for character in sys.argv[1:]:
        run(character)

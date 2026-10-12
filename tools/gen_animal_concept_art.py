#!/usr/bin/env python3
"""Batch-generate photorealistic animal concept art via the local ComfyUI API.

One image per animal card in docs/FAUNA. Shared style suffix keeps
the set consistent with the painterly/muted Baltic direction of the character
concept art (docs/CHARACTERS/img/concept) while staying photorealistic.
"""
import json
import sys
import time
import urllib.request
import uuid
from pathlib import Path

COMFY = "http://127.0.0.1:8188"
OUT_DIR = Path("/Users/artjomkurapov/git/rebel-reval/docs/FAUNA/images")
CKPT = "DreamShaper_8_pruned.safetensors"

STYLE = (
    "photorealistic wildlife natural history photograph, {subject}, "
    "soft overcast Baltic daylight, northern Estonian landscape, "
    "muted natural earth palette of grey brown moss green and dull white, "
    "detailed fur and feathers, shallow depth of field, eye-level wildlife camera, "
    "no people, no text, no watermark"
)
NEG = (
    "cartoon, illustration, drawing, painting, anime, cgi, 3d render, text, "
    "watermark, logo, people, human, deformed anatomy, extra limbs, extra legs, "
    "mutated paws, blurry, lowres, frame, border"
)

# name -> scene subject (kept short; STYLE wraps it)
PROMPTS = {
    "badger": "a European badger (Meles meles) emerging from its sett at dusk, grey black-striped head, coarse grey fur, dark forest floor with roots",
    "barn_swallow": "a barn swallow (Hirundo rustica) with glossy blue-black back, rust throat and forked tail, perched on a wooden barn beam",
    "beaver": "a Eurasian beaver (Castor fiber) sitting on a gnawed willow branch at the edge of a calm river lodge, thick brown fur",
    "brown_bear": "a large brown bear (Ursus arctos) walking through a swampy old-growth spruce forest, thick brown spring coat, powerful shoulders",
    "cat": "a shorthair medieval farm cat (Felis catus) tabby grey, sitting alert on a wooden fence in a village yard",
    "cattle": "a brown dairy cow (Baltic cattle) grazing in a fenced medieval meadow, curved horns, wet nose",
    "chicken": "a russet brown free-range hen (Gallus gallus domesticus) scratching in a farmyard",
    "common_bat": "a common noctule bat (Nyctalus noctula) in flight at dusk against a deep blue evening sky, wings spread, detailed brown fur",
    "common_blackbird": "a male common blackbird (Turdus merula) glossy black with orange beak, standing on mossy stone",
    "common_buzzard": "a common buzzard (Buteo buteo) perched on a bare branch, brown mottled plumage, sharp gaze",
    "common_chaffinch": "a male common chaffinch (Fringilla coelebs) blue-grey crown and rust breast, perched on a birch twig",
    "common_gull": "a common gull (Larus canus) standing on wet sand shoreline, pale grey wings, overcast sea behind",
    "common_kestrel": "a common kestrel (Falco tinnunculus) hovering, rust back and grey head, hunting over a winter stubble field",
    "common_nightingale": "a common nightingale (Luscinia megarhynchos) small brown songbird with warm rust tail, singing on a low bramble branch",
    "common_snipe": "a common snipe (Gallinago gallinago) crouched in wet marsh grass, long striped bill, mottled brown camouflage plumage",
    "common_tern": "a common tern (Sterna hirundo) standing on a coastal stone, pale grey wings, black cap, red bill",
    "dog": "a lean medieval mongrel village dog, brown grey short coat, standing alert on a muddy road",
    "domestic_duck": "a white domestic duck (Anas platyrhynchos domesticus) standing by a farm pond",
    "domestic_goose": "a grey domestic goose (Anser anser domesticus) hissing with neck raised in a village yard",
    "elk": "a bull elk or moose (Alces alces) with broad antlers standing in a shallow bog among birches, grey-brown coat",
    "eurasian_magpie": "a Eurasian magpie (Pica pica) perched on a wooden fence, iridescent blue-black and white plumage, long tail",
    "european_robin": "a European robin (Erithacus rubecula) with orange breast perched on a frost-covered gate",
    "goat": "a shaggy brown goat (Capra aegagrus hircus) with small horns standing on a wooden lean-to in a village",
    "great_cormorant": "a great cormorant (Phalacrocorax carbo) drying its dark wings on a coastal rock, sea behind",
    "great_spotted_woodpecker": "a great spotted woodpecker (Dendrocopos major) clinging to a pine trunk, black white red plumage",
    "great_tit": "a great tit (Parus major) with yellow belly and black head perched on a spruce branch",
    "grey_heron": "a grey heron (Ardea cinerea) standing motionless in shallow coastal reeds, pale grey plumage",
    "grey_seal": "a grey seal (Halichoerus grum) hauled out on a Baltic shingle beach, mottled grey coat",
    "greylag_goose": "a greylag goose (Anser anser) standing in a wet meadow, orange bill, grey-brown plumage",
    "hare": "a Eurasian hare (Lepus europaeus) crouched in a ploughed field, tawny brown fur, long black-tipped ears",
    "herring": "a school of Baltic herring (Clupea harengus membras) turning in clear cold green shallows near a stony shore, silver flanks, blue-green backs",
    "perch": "a European perch (Perca fluviatilis) hovering over a sunlit sandy shallows with reeds, olive body with dark vertical bars, orange fins",
    "hedgehog": "a European hedgehog (Erinaceus europaeus) foraging in leaf litter at the forest edge, sharp spines",
    "herring_gull": "a herring gull (Larus argentatus) standing on a harbour rock, pale grey mantle, yellow bill",
    "hooded_crow": "a hooded crow (Corvus cornix) with grey body and black head and wings, standing on pasture ground",
    "horse": "a sturdy medieval work horse, bay brown coat, standing on a village road with simple rope halter",
    "house_sparrow": "a male house sparrow (Passer domesticus) perched on a thatched roof edge",
    "lynx": "a Eurasian lynx (Lynx lynx) with tufted ears and spotted tawny coat, sitting alert in snowy pine forest edge",
    "mallard": "a male mallard duck (Anas platyrhynchos) with iridescent green head swimming in a calm reedy pond",
    "mute_swan": "a mute swan (Cygnus olor) with arched wings on a coastal bay, white plumage, orange bill",
    "northern_lapwing": "a northern lapwing (Vanellus vanellus) standing in a wet ploughed field, crested head, iridescent green-black plumage",
    "osprey": "an osprey (Pandion haliaetus) perched on a dead coastal pine with a fish, brown upperparts, white underparts",
    "otter": "a Eurasian otter (Lutra lutra) on a mossy riverbank stone, sleek wet brown fur",
    "pig": "a muddy domestic pig (Sus scrofa domesticus) rooting in a farmyard pen, bristly grey-pink skin",
    "pine_marten": "a pine marten (Martes martes) on a pine branch, rich brown fur with cream throat patch",
    "polecat": "a European polecat (Mustela putorius) in tall wet grass, dark brown fur with pale masked face",
    "rat": "a brown rat (Rattus norvegicus) on damp dockside planks near fishing nets",
    "red_deer": "a red deer stag (Cervus elaphus) with branching antlers standing in autumn bracken at forest edge",
    "red_fox": "a red fox (Vulpes vulpes) trotting across a frosty stubble field, rust red coat, bushy white-tipped tail",
    "ringed_seal": "a ringed seal (Pusa hispida) resting on a Baltic ice floe, ringed grey pelt",
    "roe_deer": "a roe deer (Capreolus capreolus) stepping out of a birch thicket into a meadow, reddish summer coat, small antlers",
    "rook": "a rook (Corvus frugilegus) standing in a ploughed field, glossy black plumage with bare grey face",
    "sheep": "a woolly white sheep (Ovis aries) grazing in a coastal meadow",
    "skylark": "a skylark (Alauda arvensis) hovering in mid-song above a spring field, streaked brown plumage, small crest",
    "song_thrush": "a song thrush (Turdus philomelos) with spotted cream breast on a mossy stone, broken snail shell beside it",
    "squirrel": "a Eurasian red squirrel (Sciurus vulgaris) sitting on a spruce branch with a cone, rust red fur, ear tufts",
    "stoat": "a stoat (Mustela erminea) in summer brown coat standing alert on a rough stone wall",
    "tawny_owl": "a tawny owl (Strix aluco) perched on an old oak branch at night, mottled brown plumage, dark round eyes",
    "western_jackdaw": "a western jackdaw (Coloeus monedula) with grey nape and pale eye perched on a church ledge",
    "white_tailed_eagle": "a white-tailed eagle (Haliaeetus albicilla) perched on a coastal cliff rock, massive pale head, hooked yellow bill",
    "wild_boar": "a wild boar (Sus scrofa) boar with dark bristly mane rooting in autumn forest mud, tusks visible",
    "wolf": "a grey wolf (Canis lupus) standing in a late-winter spruce forest with dirty snow, thick grey-brown winter coat, alert amber eyes",
    "yellowhammer": "a male yellowhammer (Emberiza citrinella) with bright yellow head perched on a hawthorn branch",
}

W, H = 768, 512  # landscape cards; SD1.5-native resolution keeps subjects sharp


def build_workflow(prompt: str) -> dict:
    return {
        "3": {"class_type": "KSampler", "inputs": {
            "cfg": 7.0, "denoise": 1.0, "latent_image": ["5", 0], "model": ["4", 0],
            "negative": ["7", 0], "positive": ["6", 0], "sampler_name": "dpmpp_2m",
            "scheduler": "karras", "seed": int.from_bytes(__import__("os").urandom(4), "big"),
            "steps": 28}},
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"batch_size": 1, "height": H, "width": W}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["4", 1], "text": prompt}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["4", 1], "text": NEG}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": "animals", "images": ["8", 0]}},
    }


def post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(
        COMFY + path, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read())


def history_entry(pid: str) -> dict:
    with urllib.request.urlopen(f"{COMFY}/history/{pid}", timeout=60) as r:
        return json.loads(r.read()).get(pid, {})


def main() -> int:
    names = sys.argv[1:] or sorted(PROMPTS)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    failures = []
    for name in names:
        out = OUT_DIR / f"{name}.jpg"
        if out.exists() and out.stat().st_size > 20000:
            print(f"skip {name} (exists)")
            continue
        prompt = STYLE.format(subject=PROMPTS[name])
        try:
            pid = post("/prompt", {"prompt": build_workflow(prompt),
                                   "client_id": str(uuid.uuid4())})["prompt_id"]
        except Exception as e:
            print(f"FAIL submit {name}: {e}")
            failures.append(name)
            continue
        t0 = time.time()
        while time.time() - t0 < 300:
            h = history_entry(pid)
            if h.get("status", {}).get("completed"):
                break
            if h.get("status", {}).get("status_str") == "error":
                msg = h["status"]["messages"][-1][1].get("exception_message", "?")
                print(f"FAIL gen {name}: {msg}")
                failures.append(name)
                break
            time.sleep(2)
        else:
            print(f"FAIL timeout {name}")
            failures.append(name)
            continue
        try:
            outs = h["outputs"]["9"]["images"]
            src = Path(COMFY.replace("http://", "http"))  # placeholder
            img = outs[0]
            url = f"{COMFY}/view?filename={img['filename']}&subfolder={img.get('subfolder','')}&type=output"
            data = urllib.request.urlopen(url, timeout=60).read()
            png = OUT_DIR / f"{name}.png"
            png.write_bytes(data)
            # convert to jpg via sips to keep repo small
            import subprocess
            subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "82",
                            str(png), "--out", str(out)], check=True, capture_output=True)
            png.unlink()
            # guard against blank (single-colour) MPS renders; retry on next loop pass
            from PIL import Image, ImageStat
            if ImageStat.Stat(Image.open(out).convert("L")).stddev[0] < 20:
                out.unlink()
                print(f"blank {name}, will retry")
                failures.append(name)
                continue
            print(f"ok {name} ({time.time()-t0:.0f}s)")
        except Exception as e:
            print(f"FAIL save {name}: {e}")
            failures.append(name)
    if failures:
        print("FAILURES:", " ".join(failures))
        return 1
    print("ALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

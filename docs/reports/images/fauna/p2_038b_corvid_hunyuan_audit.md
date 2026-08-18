# P2-038b Corvid Hunyuan3D audit closeout

## Scope

This report records the required rerun attempt for the optional Hunyuan3D upgrade of the four retained perched corvids:

- hooded crow
- rook
- western jackdaw
- Eurasian magpie

The candidate route is local ComfyUI Hunyuan3D v2 single-image generation. Candidate output must remain isolated under `generated/comfyui/bird_corvid_v1/candidates/`; production files under `assets/birds/**` must not be overwritten during generation.

## Rerun precondition and result

Checked on 2026-08-18 at 15:36:06 Europe/Tallinn (`2026-08-18T15:36:06+03:00`):

```text
GET http://127.0.0.1:8188/system_stats
HTTP_STATUS=000
curl exit=7
curl: Failed to connect to 127.0.0.1 port 8188: Connection refused
```

The backend was unavailable before job creation. No ComfyUI job was submitted, no checkpoint inventory could be queried, and no Hunyuan3D candidate GLB was generated. The checkpoint `hunyuan3d-dit-v2-mv_fp16.safetensors` is therefore **not established as installed** in this run.

The retained API-format workflow remains valid as a single-image template:

- one `LoadImage` node;
- one `Hunyuan3Dv2Conditioning` node;
- one `SaveGLB` output;
- fixed seed `194038`;
- reference template currently points at `eurasian_magpie_reference.jpg`.

The four reference inputs remain available at:

- `generated/comfyui/bird_corvid_v1/references/hooded_crow_reference.jpg`
- `generated/comfyui/bird_corvid_v1/references/rook_reference.jpg`
- `generated/comfyui/bird_corvid_v1/references/western_jackdaw_reference.jpg`
- `generated/comfyui/bird_corvid_v1/references/eurasian_magpie_reference.jpg`

## Candidate audit status

| Gate | Result | Evidence |
|---|---|---|
| ComfyUI `/system_stats` | Blocked | Connection refused, HTTP status `000`, curl exit `7` |
| Hunyuan checkpoint availability | Not established | Backend was unavailable before checkpoint query |
| Candidate job creation | Not run | No job submitted after failed precondition |
| Candidate count | `0` | `generated/comfyui/bird_corvid_v1/candidate_audit.json` |
| Front/side/back anatomy | Not run | No candidate mesh exists |
| Topology and UV audit | Not run for candidates | No candidate mesh exists |
| Materials and PBR audit | Not run for candidates | No candidate mesh exists |
| Grounding and catalog-scale audit | Not run for candidates | No candidate mesh exists |
| Production replacement | Not allowed | Deterministic fallback remains the approved production route |

The existing JSON ledger remains authoritative for the blocked state:

- `generated/comfyui/bird_corvid_v1/candidate_audit.json`
- `generated/comfyui/bird_corvid_v1/state.json`
- `generated/comfyui/bird_corvid_v1/report.json`

## Retained fallback verification

The deterministic Blender fallback GLBs were not modified. Direct scoped inspection on the four production files found that all files are readable binary glTF assets, remain below the 8,000-triangle budget, and pass the fauna embedded normal/metallic-roughness texture contract.

| Species | Asset | Triangles | Imported dimensions (m) | Ground min Z (m) | SHA-256 |
|---|---|---:|---|---:|---|
| hooded crow | `assets/birds/hooded_crow/perched.glb` | 2,624 | 0.312213 x 0.401420 x 0.634831 | 0.004346 | `e80c0dd7a517efec0b563253aa53b466d94f3169bfb50048d669a5e4f8ce69c5` |
| rook | `assets/birds/rook/perched.glb` | 2,624 | 0.287244 x 0.378950 x 0.598631 | 0.004346 | `61261788aea92f6097ea8dd5a8df6f1edbb8a22a918936c608e5b4f5a9de6ec9` |
| western jackdaw | `assets/birds/western_jackdaw/perched.glb` | 2,820 | 0.254754 x 0.340621 x 0.467631 | 0.004346 | `a1c6bb28bd4be210bb90b09e6f294717433ab5abc525bd189bbffa614441966a` |
| Eurasian magpie | `assets/birds/eurasian_magpie/perched.glb` | 2,948 | 0.262250 x 0.356361 x 0.676595 | 0.004346 | `fcd9ef22c549fcb4557dd7c477aae6b5abaa2bd42f80220004ddeb6155d44d61` |

The fallback material probe passed for all four files. The existing ledger also records the intentional UV limitation: `TEXCOORD_0` is absent, so UV-dependent PBR sampling is not counted as passed. This is not a Hunyuan candidate result and does not justify a production replacement.

The fallback-specific identity cues remain documented and unchanged:

- hooded crow: two-tone torso/chest material separation;
- rook: pale bill-base cue;
- western jackdaw: silver nape cue;
- Eurasian magpie: four graduated tail vanes.

## Decision

Keep the deterministic Blender corvid GLBs in production. Do not create or promote Hunyuan3D candidates until the local ComfyUI endpoint responds and the named checkpoint is confirmed. On the next available run, stage all four references, generate isolated candidates, audit front/side/back anatomy, topology, materials and UVs, grounding, catalog scale, triangle budget, and the hooded-crow/magpie critical cues, then run the scoped bird, PBR, and provenance validators before considering replacement.

No production asset or shared provenance manifest was changed by this blocked rerun.

# R-561 Lower Town gameplay-scale evidence audit

**Task:** R-561 / P0-101 gameplay-scale day/night evidence verification
**Parent:** R-108 / P0-101
**Verification date:** 2026-08-18
**Map:** `lower_town_slice` / Workers' District
**Checkout:** `aff972de` (`main`), shared worktree dirty with unrelated WIP
**Decision:** **PACKET INTEGRITY PASS; VISUAL ACCEPTANCE BLOCKED.**

## Scope and decision boundary

This report audits the R-491 capture matrix against the completed R-486 stable-ID inventory. It does not author or promote evidence. A row is **PASS** only when a matched day/night gameplay-scale pair identifies the authored stable ID(s) and supports the requested observation. A valid, non-blank route crop without stable-ID or visual observation metadata remains **BLOCKED**.

The existing packet is valid capture-capability evidence. It is not evidence that every house tier, material, roof, wear state, special building, fortification surface, or dated landmark silhouette is visually readable.

## Inputs and inventory cross-check

| Input | Result | Evidence |
|---|---|---|
| R-491 matrix | **PASS as the audit contract** | `docs/reports/lower_town_p0_101_capture_matrix.md` contains the required camera, renderer, viewport, map-revision, day/night, stable-ID, and observation fields. |
| R-486 inventory | **PASS** | `docs/reports/lower_town_p0_101_landmark_inventory.md` records 91 authored stable records: 53 houses, 36 walls, and 2 view-only gate arches. |
| Matrix stable IDs | **PASS** | Independent check found 91 explicit matrix IDs; all 91 occur in the R-486 inventory and all 91 occur in `content/maps/lower_town_slice.rrmap`. No matrix ID is orphaned or silently substituted. |
| Ordinary tiers | **SOURCE EVIDENCE ONLY** | R-486 records 14 `merchant_stone`, 14 `merchant_timber`, and 15 `craft_boda` houses. Source counts do not prove gameplay-scale silhouette or material readability. |
| Clean-checkout map revision | **BLOCKED** | After Godot import, the detached checkout cannot parse `elevation_area` / `elevation_ramp` in `content/maps/lower_town_slice.rrmap`; production definition loading returns an empty map. This is a baseline parser blocker, not a packet-image defect. |

## Packet integrity results

| Check | Result | Evidence |
|---|---|---|
| Production map target | **PASS in current checkout** | Manifest `map_id=lower_town_slice`; capture runner calls `LowerTownSlice.create()` and uses the authored route anchors. |
| Manifest metadata | **PASS** | `capture_manifest.json` records schema `r-560-lower-town-p0-101-capture-v1`, map fingerprint `e8cde197067d824d1efd46b399506f6d86158a506cd92bf5d6c6b5552f4209b2`, `gl_compatibility`, `1280x720`, orthographic size `33.75`, camera pitch `-30`, yaw `45`, camera intent, anchors, focus, and output paths. |
| Matched day/night pairs | **PASS** | Four presets each contain exactly one `day` and one `night` plate; every pair has the same `framing_key`, focus cell, focus height, orthographic size, pitch, and yaw. |
| Image dimensions | **PASS** | All eight tracked PNGs decode as `1280x720`. |
| Non-blank output | **PASS** | All eight PNGs have valid signatures, payloads above 1 KiB, and non-constant RGBA extrema. |
| Focused current-checkout contract | **PASS** | `test_capture_lower_town_p0_101.gd`: 4 tests, 0 failures, 0 errors, exit 0. Godot emitted only known shutdown ObjectDB/resource-leak diagnostics. |
| Fresh clean-checkout import | **PASS** | Detached worktree at `aff972de` imported with exit 0 before the smoke run. |
| Fresh clean-checkout focused contract | **BLOCKED** | Exit 1: four `unknown_command` diagnostics at RRMap lines 14, 17, 20, and 22 for `elevation_area` / `elevation_ramp`, followed by 10 test failures and 8 errors because the production map definition is empty. |
| Fresh clean-checkout capture smoke | **BLOCKED** | Exit 1 with `Unexpected production map for P0-101 capture`; no fresh rerender is claimed. The existing eight tracked PNGs still pass the independent file check, but that does not make them fresh clean-checkout outputs. |

## R-491 matrix row decisions

Every visual row is listed below. The route packet result is separated from the requested surface observation so that a valid camera crop is not misreported as art acceptance.

| Matrix row / required coverage | Day evidence | Night evidence | Result | Exact blocker / owner |
|---|---|---|---|---|
| Representative `merchant_stone` frontage | Route crops are available, but no visible stable house ID is recorded | Matching route crops | **BLOCKED** | No tier-identified gameplay observation; R-532 / R-487 must annotate a visible `merchant_stone` record and silhouette. |
| Representative `merchant_timber` frontage | Route crops are available, but no visible stable house ID is recorded | Matching route crops | **BLOCKED** | No tier-identified gameplay observation; R-532 / R-487 must annotate a visible `merchant_timber` record and silhouette. |
| Representative `craft_boda` frontage | Route crops are available, but no visible stable house ID is recorded | Matching route crops | **BLOCKED** | No tier-identified gameplay observation; R-532 / R-487 must annotate compact massing and absence of merchant hoist treatment. |
| Repeated frontage / variation audit | Four route day plates | Four matching route night plates | **BLOCKED** | No per-surface review or authored repetition threshold is linked; R-532 / R-487 owns the observation. |
| Log / plank / plaster / limestone wall families | Ordinary-frontage candidates only | Matching candidates only | **BLOCKED** | Source inventory is not visual proof; R-532 / R-487 must identify each visible family against stable IDs. |
| Tile / shingle / thatch roof covers | Ordinary-frontage candidates only | Matching candidates only | **BLOCKED** | No roof-family annotation or night readability review; R-532 / R-487 owns the evidence. |
| Localized wear and repaired states | Forge/brewery and ordinary-frontage candidates | Matching night candidates | **BLOCKED** | Non-blank pixels do not prove mud, wet, grime, soot, or repairs read at gameplay scale; R-532 / R-487 must annotate authored wear states. |
| Nine default-path special/use-site buildings | Forge/brewery route candidates only | Matching night candidates only | **BLOCKED** | The packet does not identify all nine records or prove their silhouettes; R-533 / R-488 / R-489 owns stable-ID route review. |
| `st_catherines_church` | No dedicated church approach plate | No dedicated church approach plate | **BLOCKED** | No stable-ID approach metadata or named historical/art review; R-533 / R-492 / R-537 owns the missing pair and sign-off. |
| Inner Viru Gate: towers, jambs, arch | `checkpoint_west_to_checkpoint_east_day.png` is a candidate gate route crop | Matching night crop | **BLOCKED** | Pair lacks observed IDs `viru_gate_north_tower`, `viru_gate_south_tower`, both jambs, and `viru_gate_arch`; R-533 / R-488 / R-492 owns the gate review. |
| Viru foregate: walls, towers, jambs, arch | Same checkpoint candidate only | Same checkpoint candidate only | **BLOCKED** | Current preset does not identify foregate records separately; R-533 / R-488 / R-492 owns a foregate-specific pair. |
| Remaining fortification and precinct walls | Route context only | Matching route context only | **BLOCKED** | No per-wall, wall-walk, sealed-join, monastery-wall, or smithy-fence observations; R-533 / R-488 / R-492 owns the review. |
| Route-scale proof special buildings are not enlarged ordinary houses | Forge/brewery and checkpoint candidates | Matching night candidates | **BLOCKED** | No per-building exceptional renderer observation or silhouette comparison; R-533 / R-489 / R-537 owns the proof. |
| Existing playable route and landmark approach reproducibility | Four named day plates | Four matching named night plates | **PASS for packet reproducibility** | Packet contract is green. This PASS does not close any blocked surface row above. |

The grouped stable-ID rows in the matrix remain covered by the same decisions: `monastery_cloister` / `monastery_barn`, `guild_storehouse` / `public_bathhouse`, `karja_gate_house` / `foaming_mug_brewery` / `kalev_smithy`, `muurivahe_house_north` / `south_apron_wall_walk_hut`, both gate arches, all Viru and foregate wall records, city-wall bends and seals, monastery precinct walls, and both smithy-yard fences. The ID audit confirms that these names resolve to R-486/source records; no grouped row has a matched stable-ID visual observation, so none is promoted to PASS.

## Reproduction commands

### Current-checkout focused contract

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . \
  --script tools/run_godot_tests.gd -- \
  --filter=test_capture_lower_town_p0_101
```

Observed: `1 file(s), 4 test(s), 0 failure(s), 0 error(s)`, exit 0.

### Dedicated capture command

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_lower_town_p0_101.gd
```

This command is the authored packet command. In the detached clean checkout at `aff972de` it was rerun after import and stopped at the RRMap parser blocker before producing a fresh packet.

### Independent packet file check

```bash
python3 - <<'PY'
import json
import struct
from pathlib import Path
root = Path("docs/reports/images/lower_town_p0_101")
manifest = json.loads((root / "capture_manifest.json").read_text())
errors = []
by_preset = {}
for plate in manifest["plates"]:
    path = Path(plate["output"].replace("res://", ""))
    if not path.exists():
        errors.append(f"missing:{path}")
        continue
    payload = path.read_bytes()
    if payload[:8] != b"\\x89PNG\\r\\n\\x1a\\n":
        errors.append(f"signature:{path}")
    width, height = struct.unpack(">II", payload[16:24])
    if (width, height) != (1280, 720):
        errors.append(f"dimensions:{path}:{width}x{height}")
    if len(payload) <= 1024:
        errors.append(f"blank_payload:{path}")
    by_preset.setdefault(plate["preset_id"], {})[plate["time_of_day"]] = plate
for preset, pair in by_preset.items():
    if set(pair) != {"day", "night"}:
        errors.append(f"pair:{preset}")
    elif pair["day"]["framing_key"] != pair["night"]["framing_key"]:
        errors.append(f"framing:{preset}")
print(f"R561_PACKET plates={len(manifest['plates'])} presets={len(by_preset)} errors={len(errors)}")
for error in errors:
    print(error)
raise SystemExit(bool(errors))
PY
```

Observed: `R561_PACKET plates=8 presets=4 errors=0`.

### Stable-ID cross-check

The audit also compared every explicit backtick ID in the matrix with both R-486 inventory IDs and the second token of every `building` / `landmark` record in `content/maps/lower_town_slice.rrmap`: `matrix_ids=91`, `missing_inventory=0`, `missing_source=0`.

## Closeout

R-561's audit deliverable is complete and should remain **in review**, not `done`: the packet is reproducible and structurally valid in the current shared checkout, while all R-108 surface clauses that lack stable-ID visual observations remain explicitly **BLOCKED**. The clean-checkout rerun adds a separate baseline blocker at the RRMap parser boundary. Existing owners are sufficient; no duplicate follow-up task is created.

The next acceptance step is to clear the existing `elevation_area` / `elevation_ramp` parser boundary in the owning elevation/runtime work, then extend the route capture review with stable-ID observations for the three tiers, material/roof/wear families, special buildings, St. Catherine's, inner Viru Gate, foregate, and wall continuity. Do not close R-108 from the current packet.

## Sources

- [`lower_town_p0_101_capture_matrix.md`](lower_town_p0_101_capture_matrix.md)
- [`lower_town_p0_101_landmark_inventory.md`](lower_town_p0_101_landmark_inventory.md)
- [`capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)
- [`r536_lower_town_day_night_capture_verification.md`](r536_lower_town_day_night_capture_verification.md)
- [`tools/capture_lower_town_p0_101.gd`](../../tools/capture_lower_town_p0_101.gd)
- [`tests/godot/test_capture_lower_town_p0_101.gd`](../../tests/godot/test_capture_lower_town_p0_101.gd)
- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)

# R-597 Lower Town frontage rhythm and house-tier verification

**Task:** R-597 / P0-100 decomposition: verify frontage rhythm and house-tier coverage
**Verification date:** 2026-09-02
**Map:** `lower_town_slice` / Workers' District
**Checkout:** `0931b5201004545c0953486163bd3486fcd2f1e6` (`main`)
**Worktree boundary:** shared dirty worktree with unrelated staged, modified, and untracked WIP; this report is the only file owned by R-597 in this change.
**Map source SHA-256:** `67d6593bac4fa26a2fcf60a7206bc2938023eaadda20da7e3c4051cb3c6ddc9`
**Decision:** **SOURCE-LEVEL PASS; INTEGRATED HEADLESS CONTRACT BLOCKED; VISUAL ACCEPTANCE NOT PROVEN.**

## Scope and decision rule

This is a bounded verification report. It does not modify `content/maps/lower_town_slice.rrmap`, the authoring contract, runtime map definitions, parser support, house assets, capture PNGs, or test fixtures.

The source-level result is a deterministic audit of the authored RRMap records and the frontage rules declared in [`lower_town_authoring_contract.json`](../data/lower_town_authoring_contract.json). It proves authored counts and declared width coverage only. It does not prove that the current parser, compiled `MapDefinition`, renderer, or gameplay camera resolves those records.

The integrated result requires both focused Godot suites to parse the RRMap, resolve the runtime definition, and exercise the tiered records. Because the current source snapshot emits parser diagnostics and the runtime definition does not expose the expected records, the integrated contract remains blocked. Existing day/night plates are not promoted to visual acceptance without stable-ID observations and review metadata.

## Source-level audit

The audit used the current RRMap at the SHA above and the contract's `cell_to_m=1` frontage convention. For frontage width, the same directional rule as the contract test was used: `house.north`/`house.south` use the source `w` dimension, while `house.east`/`house.west` use `h`.

| Check | Observed result | Verdict |
|---|---:|---|
| Authored RRMap records | 91 total: 89 `building` records and 2 `landmark` records | **PASS** |
| Building inventory | 53 `house` records and 36 `wall` records | **PASS** |
| Tiered ordinary houses | 43 records | **PASS** |
| `merchant_stone` coverage | 14 houses | **PASS** |
| `merchant_timber` coverage | 14 houses | **PASS** |
| `craft_boda` coverage | 15 houses | **PASS** |
| Default public frontage | 41/43 tiered houses within `7-11m`; median `9m` | **PASS** |
| Documented frontage exceptions | `kaik_house_mid=12m`; `viru_house_mid=14m` | **PASS** |
| Exception rule | Both use `merchant_irregular_frontage_m` with declared range `12-14m` and reasons | **PASS** |
| Contracted rear/service exclusions | Eight IDs are declared in `rear_service_buildings`, but are absent from this RRMap snapshot | **BLOCKED - source/contract drift** |

The source-level PASS therefore covers the authored tier distribution and the 7-11m rhythm with its two explicit irregular merchant rows. It does not claim that the full contract is currently resolvable.

### Authored frontage exceptions

| Stable ID | Source style / footprint | Frontage result | Contract reason |
|---|---|---:|---|
| `kaik_house_mid` | `house.north.h120.20`, footprint `12x8` | `12m` | Wider guild-side merchant compound row |
| `viru_house_mid` | `house.south.h128.26`, footprint `14x10` | `14m` | Wider Viru-side merchant compound row |

The eight contract-declared rear/service IDs are `saddlers_rear_workshop`, `coopers_rear_workshop`, `sauna_rear_boda`, `rope_makers_rear_store`, `karja_rear_boda`, `brewery_rear_store`, `smithy_rear_shed`, and `carriers_barn`. A literal `building <id>` scan of the current RRMap finds none of them. They must not be counted as present or visually covered by this report.

## Integrated headless verification

### Authoring contract suite

Command:

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . \
  --script res://tools/run_godot_tests.gd -- \
  --filter=test_lower_town_authoring_contract
```

Observed summary:

```text
Godot headless tests: discovered 1 file(s).
Godot headless tests: 1 file(s), 3 test(s), 217 failure(s), 8 error(s).
```

The focused frontage declaration method itself reached a PASS, but the suite is not green. The first runtime construction reports four parser diagnostics:

```text
res://content/maps/lower_town_slice.rrmap:14:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:17:1: error[unknown_command]: unknown command 'elevation_ramp'
res://content/maps/lower_town_slice.rrmap:20:1: error[unknown_command]: unknown command 'elevation_area'
res://content/maps/lower_town_slice.rrmap:22:1: error[unknown_command]: unknown command 'elevation_area'
```

After the parse failure, runtime resolution reports the expected compiled map as empty and cannot resolve stable anchors/props or contract-owned records. Representative failures include:

- `Expected <lower_town_slice> but got <>`.
- Missing compiled anchors: `street_start`, `smithy_door`, `brewery_door`, `checkpoint_west`, and `checkpoint_east`.
- Missing compiled prop: `cistern`.
- Contract references reported unknown after the failed runtime build, including `market_row_house`, `apothecary_house`, `merchants_house`, `foaming_mug_brewery`, `market_stall_gate`, and `customers_street`.
- The deterministic width method also reports the eight rear/service IDs as missing from the RRMap and runtime, and cannot complete its final exception-report assertion.

### House-tier suite

Command:

```bash
"$GODOT_BIN" --headless --path . \
  --script res://tools/run_godot_tests.gd -- \
  --filter=test_burgher_house_tiers
```

Observed summary:

```text
Godot headless tests: discovered 1 file(s).
Godot headless tests: 1 file(s), 5 test(s), 92 failure(s), 12 error(s).
```

Two isolated renderer/precedence checks reached PASS (`test_exceptional_registry_wins_over_house_tier_and_building_kind` and `test_tier_fallback_and_authored_material_precedence_are_deterministic`), but the Lower Town definition-dependent methods are blocked by the same four unknown elevation commands and then report missing authored/runtime records. The tier suite cannot therefore certify compiled coverage, wall/roof material variation, or weathering variation for the 43 source-level tiered houses.

### Integrated verdict

| Gate | Result | Reason |
|---|---|---|
| RRMap parser | **BLOCKED** | `elevation_area` and `elevation_ramp` are unknown to the current parser path |
| Contract-to-runtime resolution | **BLOCKED** | Runtime definition is empty after parse failure; stable IDs and contract references do not resolve |
| Compiled house-tier coverage | **BLOCKED** | Tier tests report missing Lower Town records and cannot build the authored set |
| Source-level tier/frontage audit | **PASS** | 43 tiered houses, all three tiers present, 41 default widths, two declared exceptions |

These are separate outcomes. The parser/runtime blockers must not be “fixed” by weakening the acceptance contract or by treating static source counts as compiled coverage.

## Visual acceptance status

**NOT PROVEN.** The existing packet under [`images/lower_town_p0_101/`](images/lower_town_p0_101/) contains matched day/night route plates, but its manifest records route anchors and `not_reviewed` stable-ID observation rows rather than reviewed visible house IDs and tier observations. Its recorded authored-map fingerprint is also an older snapshot (`6ae0b82a0a46a7391cb5db5a0bb02e562756def8073fe08cf63beebd7ace7e50`) and must not be silently substituted for the current RRMap SHA in this report.

Accordingly, this verification does not accept gameplay-scale visual rhythm, repeated frontage readability, material/roof differentiation, or day/night tier readability. A future visual review needs a current-source capture packet with named stable IDs, matched framing, and reviewer annotations.

## Reproduction and evidence sources

Source-level spot checks:

```bash
shasum -a 256 content/maps/lower_town_slice.rrmap

grep -c '^building ' content/maps/lower_town_slice.rrmap
grep -c '^landmark ' content/maps/lower_town_slice.rrmap
grep -c ' house_tier=' content/maps/lower_town_slice.rrmap
grep -c 'house_tier=merchant_stone' content/maps/lower_town_slice.rrmap
grep -c 'house_tier=merchant_timber' content/maps/lower_town_slice.rrmap
grep -c 'house_tier=craft_boda' content/maps/lower_town_slice.rrmap
```

The exact deterministic frontage implementation is in `test_lower_town_frontage_width_report_is_deterministic()` and `_source_frontage_width()` in [`test_lower_town_authoring_contract.gd`](../../tests/godot/test_lower_town_authoring_contract.gd). The observed Godot outputs were captured in `/tmp/r597-authoring-contract.log` and `/tmp/r597-house-tiers.log` during this verification session.

Sources:

- [`content/maps/lower_town_slice.rrmap`](../../content/maps/lower_town_slice.rrmap)
- [`docs/data/lower_town_authoring_contract.json`](../data/lower_town_authoring_contract.json)
- [`tests/godot/test_lower_town_authoring_contract.gd`](../../tests/godot/test_lower_town_authoring_contract.gd)
- [`tests/godot/test_burgher_house_tiers.gd`](../../tests/godot/test_burgher_house_tiers.gd)
- [`docs/reports/r616_lower_town_gameplay_evidence_verification.md`](r616_lower_town_gameplay_evidence_verification.md)
- [`docs/reports/images/lower_town_p0_101/capture_manifest.json`](images/lower_town_p0_101/capture_manifest.json)

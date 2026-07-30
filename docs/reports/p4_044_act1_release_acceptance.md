# P4-044 Act 1 release acceptance

Task: **P4-044**  
Slice: `act1-standalone-candidate`  
Role: QA  
Date: 2026-07-30  
Environment: macOS arm64, Godot 4.7.1 (`/Applications/Godot.app/Contents/MacOS/Godot`)

Independent release acceptance over the exact **P4-013** Act 1 package. This row records acceptance evidence only. It does not edit package inputs, runtime, content, assets, export settings, or the P4-012 maintainer report.

## Package bind

| Field | Value |
|-------|-------|
| Export preset | `act1` |
| Package path | `build/act1/rr.dmg` |
| Package bytes | 1143742554 |
| Package SHA-256 | `ea3cf41493394ab6bd01e17de38011b05bf3ee199fd4710a08a4eb3dc1eafbdc` |
| Fingerprint | `build/act1/package_fingerprint.json` |
| SHA sidecar | `build/act1/PACKAGE_SHA256.txt` |
| Application version | `0.2.0-act1` |
| Release tag | `v0.2.0-act1` |
| Gate report | `docs/reports/p4_012_act1_gate.md` |

Live DMG SHA-256 and byte size match the P4-013 fingerprint and the release manifest.

## Verdict

**Pass.** The exact P4-013 Act 1 package installs, launches, saves, loads, and exits on macOS; Act 1 branch traversal stays green; package SHA/manifest fingerprint bind holds; licences, accessibility, and supported-input contracts hold. No unresolved critical/high finding.

## Commands

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
tools/verify_act1_release.sh
python3 -m unittest tests.python.test_act1_release_candidate -v
```

| Check | Result | Evidence |
|-------|--------|----------|
| Package SHA / fingerprint bind | pass | manifest, `PACKAGE_SHA256.txt`, `package_fingerprint.json`, and live `build/act1/rr.dmg` all share `ea3cf414...eafbdc` / 1143742554 bytes |
| Act 1 traversal | pass | `report_act1_traversal.py --check`; checked runner `--filter=test_act1_traversal` 8/8 |
| Accessibility | pass | `report_accessibility_checklist.py --check` |
| Licences / third-party | pass | `report_slice_third_party.py --check` - 92 assets OK |
| Content budget | pass | `report_act1_content_budget.py --check` - planned faction-line warnings only |
| Supported input | pass | `--filter=test_act1_release_acceptance` keyboard/mouse + gamepad catalog completion |
| Release acceptance suite | pass | `--filter=test_act1_release_acceptance` 7/7 |
| Clean-install packaged smoke | pass | DMG mount + `--verify-packaged-platform` prints `P3-012_PACKAGED_PLATFORM_PASS steps=install,start,save,load,exit` |

## Coverage matrix

| Area | Assertion | Result |
|------|-----------|--------|
| Exact package identity | Release manifest binds P4-013 SHA/bytes; live DMG matches | pass |
| Act 1 branches | Intended Seal/Break/Open endings remain reachable; invalid transitions stay rejected | pass |
| Save/load/exit | Clean-start -> seal boundary -> SaveService reload keeps envelope | pass |
| Supported inputs | Every catalog action has keyboard/mouse and gamepad bindings; SliceInputDriver completes both profiles | pass |
| Accessibility | Required checklist options + settings surfaces present | pass |
| Licences | THIRD_PARTY_NOTICES, CREDITS, slice third-party manifest | pass |
| macOS install/start/save/load/exit | Clean extract from `build/act1/rr.dmg` then packaged smoke | pass |

## Severity-ranked findings

| ID | Severity | Area | Status | Notes |
|----|----------|------|--------|-------|
| P4-044-N01 | low | Compatibility exit noise | accepted non-blocking | Packaged smoke still emits ParticlesShaderGLES3 / resource / RID exit leaks and ObjectDB warnings after the PASS marker. Same family as **P4-012-N01**; not a release blocker while `P3-012_PACKAGED_PLATFORM_PASS` is present. |
| P4-044-N02 | info | content budget | accepted | Faction lines `faction_line.livonian_order` and `faction_line.black_cloaks` remain planned for **P4-021**; within approved Act 1 budget. |

No unresolved critical/high finding.

## Artifacts

- `docs/data/act1_release_manifest.json`
- `docs/reports/p4_044_act1_release_acceptance.md`
- `tools/verify_act1_release.sh`
- `tests/python/test_act1_release_candidate.py`
- `tests/godot/test_act1_release_acceptance.gd`

## Handoff

- Act 1 standalone-candidate milestone acceptance is closed for the exact P4-013 package.
- Producer may stop this Current focus slice when no other focus row remains open.
- Optional later Dev hygiene may reduce Compatibility exit-leak noise (**P4-012-N01** / **P4-044-N01**); not required to keep this release accepted.

# Undress interaction: drag to remove clothes

Status: partial. The test version is implemented in the seamless city: hover, drag, garment and bare-body removal, redress with U. NPC reaction, reputation, soul-light cost and saves are planned. Scope: a sandbox test of how touching a living character feels, for an adults-only game. Out of scope for the first cut: any NPC reaction, reputation, soul-light or psyche effect, and any character that is not an adult.

Canon: invented mechanic; no historical claim. It builds on the adult nude body layer that spirit sight already uses ([`SPIRIT_SIGHT.md`](./SPIRIT_SIGHT.md), task **R-1870**) and on the per-body garment layers ([`CITIZEN_WARDROBE.md`](./CITIZEN_WARDROBE.md)).

## What the player does

1. Walk up to a character and hover the cursor over their body. The cursor becomes a **hand**.
2. Hold the left mouse button on a body part and drag **downward**. The garment covering that part comes off, following the drag, so it reads as handling a living person rather than a menu action.
3. Only the garment under the cursor goes; the rest stays on. Repeating on other parts can strip a person completely.

## Hard rules

- **Adults only.** Children and any body matching the child/boy/girl/apprentice refusal in `SpiritUndress` never show the hand cursor and cannot be undressed. Although the protagonist is now 18, the player remains explicitly excluded by the current prototype scope; this age change does not enable new interaction or nudity. Same eligibility as the spirit-sight nude layer (a body needs a `layers/nude.glb` twin).
- The effect is transient presentation in the first cut: nothing is saved, no state changes.

## First-cut behaviour (test only)

The target character does not react: no resistance, no bark, no animation change. The point is to judge the feel of the gesture. Design questions the test should answer: how far a drag must travel per garment, whether partial drag leaves a garment half-off, and which body regions map to which garment layers (hood and coif, mantle, gown or tunic, apron, belt and scrip, footwear).

## Planned later (not part of the test)

Everything here needs its own ADR/task before coding, per the scope rule in [`AGENTS.md`](../../AGENTS.md):

- **Character reaction:** resistance, refusal, flight, barks, anger, embarrassment, or willing cooperation, driven by the NPC mind ([`NPC_MIND.md`](./NPC_MIND.md)) and relationship state.
- **Bystanders:** witnesses react; guards may intervene.
- **Reputation:** faction standing and Living City Hope/Fear respond to undressing someone, by whether people saw ([`FACTIONS_AND_ECONOMY.md`](./FACTIONS_AND_ECONOMY.md), [`LIVING_CITY.md`](./LIVING_CITY.md)).
- **Inner cost:** undressing someone against their will damages the player's own soul lights or Hingepuu psyche ([`NATURAL.md`](./NATURAL.md), [`PSYCHE.md`](./PSYCHE.md), [`SPIRIT_SIGHT.md`](./SPIRIT_SIGHT.md)); a willing exchange can instead boost both people.
- **Consent as state:** willing versus forced is the axis that decides all of the above; it must be an explicit deterministic flag, never inferred.

## Implemented (test version)

- `ClothingStrip` (`scripts/characters/clothing_strip.gd`) is mounted by `CityCitizens` and registers every styled resident rig. Hover an adult: hand cursor (`CursorService.LAYER_CHARACTER`). Press on a fitted garment and drag down 56 px: that wearable (gown, apron, headscarf, boots, ...) comes off. With no layer under the cursor, dragging the bare body pulls off the baked outfit and mounts the citizen's `layers/nude.glb` twin via `SpiritUndress`. Press **U** to redress everyone.
- The asset review galleries mount the same `ClothingStrip` (`scenes/debug/asset_showcase.gd`): the characters gallery on its named variants, the small gallery on four adult citizens beside the cart.
- Minor body variants and the adult player character are refused by the current `SpiritUndress.is_protected` prototype guard.
- Verify: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_clothing_strip`.
- Limits: removing the baked outfit is all-or-nothing per body (no per-region mask yet); spirit sight closing restores the outfit of anyone it undressed, including bodies stripped by hand; nothing is saved.

## Runtime plan

- Hover test: raycast from the camera to the character's body; set the hand cursor when an eligible adult rig is hit.
- Region pick: map the hit point (bone or height band) to a garment layer in the rig's mounted garments.
- Removal: reuse the hide/restore bookkeeping of `SpiritUndress` (`scripts/combat/spirit_undress.gd`) at garment granularity, with the nude layer showing through the removed region (the baked crowd body has no skin under its outfit, so partial removal needs the per-garment layers or the nude twin masked by region).
- Verify: a `tests/godot/test_*.gd` for eligibility (adult yes, child/apprentice no), per-garment removal and restore; a capture with `tools/godot_render.sh`.

## Limits

Crowd bodies bake their outfit into one mesh, so removing a single garment from them may need the nude twin plus a region mask; this is the main open technical question for the card.

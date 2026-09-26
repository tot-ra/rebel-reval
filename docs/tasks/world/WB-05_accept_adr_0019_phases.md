# WB-05: Accept ADR 0019 and record the streaming phases and the travel boundary

Board row: **R-977**. Priority: high. Depends on: none. Gate for R-978..R-980.

## Player-facing goal

None directly. This row unblocks seamless traversal inside Reval.

## Why this is needed

ADR 0019 already answers the design question and its `Status` says so: "Proposed target
architecture... Adoption requires maintainer approval, and implementation must ship behind a
disabled feature flag until the acceptance gates below pass." The foundations are built -
`MapAlignmentMath`, `MapWorldLayout`, and `WorldHost`, which describes itself as a "Phase 2
additive-residency prototype" that "deliberately does not create players/cameras or perform scene
swaps", gated by `world_host/additive_residency_enabled` (default false).

So the work is stalled on an approval, not on a design. Nothing can proceed to phase 3 until the
status changes and the phases have owners and gates.

## Deliverable

1. **ADR 0019 `Status` updated** to accepted or rejected, with an ISO date and the maintainer's
   name. If accepted, the acceptance gates already listed in the ADR are restated as the
   release criteria for R-980.
2. **An explicit seamless-group membership list.** Which locations belong to
   `world_group_id = reval_outdoor` and are streamed, and which keep an explicit transition. The
   maintainer's stated boundary is: physically adjacent Reval districts and harbours stream;
   Saaremaa, Padise, Paide, Parnu, Poide, Kanavere, Sojamae, Harju, the sacred grove and the rebel
   kings map keep travel transitions. Every `world.*` map is `alignment=travel`. **Interiors** need
   a decision of their own - the forge, town hall, churches and tower interiors are small and are
   the transitions the player crosses most often, so record whether they stream or stay explicit,
   and why.
3. **A phase plan** in `docs/SEAMLESS_STREAMING_PLAN.md` mapping phases 3, 4 and 5 onto R-978,
   R-979 and R-980, each with its own measurable exit gate, the feature flag that stays off until
   that gate passes, and the rollback path.
4. **A measured startup baseline** to hold the work to. The recorded Lower Town figure in ADR 0019
   is about **20 ms** for compact compilation, terrain, 2D assembly and navigation, against about
   **2.93 s** for full production scene startup under the headless dummy renderer. Re-measure on
   the current tree, since the water, sky, atmosphere and crowd work landed since, and publish the
   per-stage breakdown. Streaming cannot be budgeted against a stale number.
5. **A dependency note on map activation.** Only `lower_town_slice` and `kalev_smithy` are
   `active=true`; every adjacent district is an inactive prototype, so today there is nothing to be
   seamless between. Record which activation tasks must land before R-980 can be demonstrated at
   all, and whether R-976 relief seam continuity is a prerequisite.

## Allowed files

`docs/adr/0019-seamless-contiguous-location-streaming.md`, `docs/SEAMLESS_STREAMING_PLAN.md`,
`docs/reports/seamless_startup_baseline_2026-09-26.md`,
`docs/tasks/world/WB-05_accept_adr_0019_phases.md`, `TODO.md`.

## Constraints and non-goals

No runtime behaviour change and no flag default change in this row. Do not rewrite ADR 0019's
decision - amend `Status` and append the phase mapping. Do not activate any map.

## Verification

`python3 tools/generate_active_docs_report.py --check`; the startup baseline report reproduces from
a named command; maintainer acceptance with an ISO date is present in the ADR; a second reviewer
confirms the group membership list covers every map in `content/maps/` with no map unassigned.

## Doc updates

Link `docs/SEAMLESS_STREAMING_PLAN.md` from `docs/ARCHITECTURE.md` and from this pack's README.

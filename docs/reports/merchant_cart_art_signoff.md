# A-011 Merchant-cart art sign-off

**Review date:** 2026-08-02
**Historical target:** Spring 1343 Reval, Lower Town, harbour margin, and Viru approach
**Task:** A-011 / R-8
**Inputs:** A-010 `merchant_cart_art_brief.md`, R-068 `merchant-cart-and-transport-1340s.md`, R-069 `reval-cart-tolls-and-fuhr-rent-1340s.md`, and P0-164 `merchant_cart_transport_contract.md`

## Decision

**CONDITIONAL ART-DIRECTION PASS; FINAL GAMEPLAY SIGN-OFF BLOCKED.**

The documentation pack and the authored `cart_2w` production study establish the intended Spring-1343 supply-traffic direction: a small two-wheel horse *Karren* is the urban default, while four-wheel freight and hand-barrows remain distinct exception classes. The current repository does not yet provide the complete authored kit or the corridor placements required for a final gameplay-camera acceptance. This report therefore records the accepted art boundary and the exact evidence still owned by downstream tasks; it does not claim that the three traffic locations have passed day/night review.

## Evidence inventory

| Evidence | Result | Review note |
|---|---|---|
| `docs/reports/images/merchant_carts/reference_cart_2w.png` | Present | A-010 documentation-only two-wheel Karren study |
| `docs/reports/images/merchant_carts/reference_wagon_4w.png` | Present | A-010 documentation-only heavy-wagon study |
| `docs/reports/images/merchant_carts/reference_barrow.png` | Present | A-010 documentation-only hand-barrow study |
| `generated/blender/supply_cart_v1/preview.png` | Present | Deterministic Blender production preview; not a gameplay capture |
| `assets/props/trade/supply_cart.glb` | Present | A-004 production `cart_2w` asset; A-004 remains `in_review` |
| `generated/blender/supply_cart_v1/report.json` | Present | 3,492 triangles, 1.30 m wheel track, 2 wheels, 12 spokes, zero floating objects, ground contact, open front, wicker lattice, hinged rear gate, and merchant load variant |
| Authored `wagon_4w` and `barrow` runtime kit | Missing | Owned by P2-068 / R-206, currently `todo` |
| Vanaturg, harbour, and Viru gameplay-camera day/night captures | Missing | Corridor placement is owned by P2-069 / R-207, currently `todo`; no substitute image is accepted |
| Class-tagged corridor evidence and seasonal traffic state | Missing | P2-069 and P2-070 own placement and runtime traffic wiring; current map records remain legacy `cart` / `farm_cart` entries in the reviewed locations |

The three A-010 PNGs and the Blender preview are art-direction evidence only. They are not archaeological reconstructions, licensed source photographs, gameplay captures, or permission to register documentation images as runtime assets.

## Vehicle-class review

| Class | Provisional art verdict | Required gameplay read | Current boundary |
|---|---|---|---|
| `cart_2w` | **Pass as production art target; final placement acceptance pending** | Small open-front horse *Karren*, approximately 1.3 m track, lattice/wicker sides, hinged rear gate, modest sacks/barrel load, and no military silhouette | The GLB and generator report satisfy the geometry/material checks listed above. Horse pairing, corridor assignment, and day/night readability are not proven by this report. |
| `wagon_4w` | **Reference target only** | Broad four-wheel heavy-load wagon restricted to harbour or wall-building margins; never ordinary alley or forum traffic | No authored production wagon or gameplay capture is present. P2-068 owns the kit and P2-069 owns its placement restrictions. |
| `barrow` | **Reference target only** | Human-scale hand or sack barrow for the forum throat and shop diele, with no horse shaft or cart queue footprint | The reference plate exists, but no authored production barrow or gameplay capture is present. P2-068 owns the kit. |

## R-068 ship-decision review

| # | Decision | A-011 review result | Final evidence still required |
|---:|---|---|---|
| 1 | Two-wheel *Karren* is the default urban vehicle | **Pass for the art target** | Confirm `cart_2w` is the default on Vanaturg, Pikk/Lai, ordinary harbour approaches, and Viru before the siege stall. |
| 2 | Four-wheel wagon is a harbour/wall-yard exception | **Pass as a rule; not gameplay-verified** | Capture harbour margin and wall-yard context after P2-068/P2-069 author the class. |
| 3 | Hand barrow serves forum/shop scale | **Pass as a rule; not gameplay-verified** | Capture the forum throat or shop-diele scale without enlarging the barrow to cart scale. |
| 4 | Town supply uses a horse, not an ox default | **Partially evidenced** | The `cart_2w` asset is the correct cart target, but draught pairing is not part of the available A-011 capture evidence. P2-068 must show the horse or static shaft placeholder. |
| 5 | Spring loads include grain, beer, salt, iron, charcoal, hemp/flax, hides, and empty barrels | **Partially evidenced** | The production preview confirms two sacks and one barrel. The full load-prop kit remains owned by P2-068. |
| 6 | Track metric is approximately 1.3 m | **Pass for `cart_2w` asset** | Preserve the 1.30 m metric when the production kit is placed on authored corridors. |
| 7 | Inland grain and charcoal stall after 23 April; harbour lighter-to-cart may continue | **Not assessed** | Requires P2-070 seasonal traffic wiring and matched pre/post-siege captures. |
| 8 | Cart art must not imply a settled toll or wheel tax | **Pass as an art constraint; placement/UI not assessed** | Keep `cart_toll_pfennig` null and reject toll booths, axle counters, or fee labels when corridor/runtime evidence is reviewed. |

## R-069 rejection review

The reviewed cart art contains no armour, firing positions, defensive breastwork, coach springs, rubber tyres, covered Conestoga body, ox-team default, or municipal dung-cart livery. The two-wheel production asset reads as an ordinary merchant cart rather than a war wagon. This is a bounded asset review only: it does not accept any unreviewed map prop, UI, or traffic controller as historically accurate.

R-069 remains a gap for an attested 1340-1343 cart toll. No sign-off may introduce a gate toll booth, axle counter, pfennig-per-wheel label, or other representation of a settled wheel levy. Cargo weighing, harbour dues, market-order fines, and curfew enforcement must remain separate systems.

## Required closeout evidence

A-011 can move from conditional review to final art acceptance only when all of the following are attached under this report's allowed evidence boundary:

1. A final gameplay-scale day and night capture of the Vanaturg east throat, showing `cart_2w` as the default and no twin-cart staging on a sub-3 m back lane.
2. A final gameplay-scale day and night capture of the harbour approach, showing ordinary `cart_2w` traffic and any `wagon_4w` only on the harbour/timber margin.
3. A final gameplay-scale day and night capture of the Viru apron, showing the inbound grain queue in the pre-siege state and its post-23-April stall state where applicable.
4. Authored `wagon_4w` and `barrow` assets with gameplay-scale evidence, or an explicit scope decision that keeps those classes deferred without claiming them accepted.
5. An annotation for each capture against R-068 ship decisions 1-8 and the R-069 toll-gap rejection rules.
6. Confirmation that runtime assets and traffic wiring are owned by A-004/P2-068/P2-069/P2-070, while this report remains an independent art review.

## Handoff and blockers

- **A-004 / R-3:** finish Canon review of the `cart_2w` production asset and its provenance boundary.
- **P2-068 / R-206:** author and wire `wagon_4w`, `barrow`, load props, and horse/static-shaft presentation.
- **P2-069 / R-207:** author the Vanaturg, Pikk/Lai, harbour, Viru, and wall-yard corridor placements, including `wheel_rut_spacing: 1.3 m`, width restrictions, and no toll booths.
- **P2-070 / R-208:** wire day/night and post-23-April traffic state, then provide the gameplay capture set required by this review.

No new follow-up task is created here because each acceptance blocker already has an owning board row. A-011 remains open for final Canon review until those owners provide the missing evidence.

## Sources

- [`merchant_cart_art_brief.md`](merchant_cart_art_brief.md) - A-010 vehicle matrix, corridor rules, confidence labels, and rejection list.
- [`merchant_cart_transport_contract.md`](merchant_cart_transport_contract.md) - P0-164 class allowlist, metric constants, and R-069 gap handling.
- [`history/dossiers/economy/merchant-cart-and-transport-1340s.md`](../../history/dossiers/economy/merchant-cart-and-transport-1340s.md) - R-068 Spring-1343 transport decisions.
- [`history/dossiers/economy/reval-cart-tolls-and-fuhr-rent-1340s.md`](../../history/dossiers/economy/reval-cart-tolls-and-fuhr-rent-1340s.md) - R-069 toll-gap evidence and rejection boundary.
- [`generated/blender/supply_cart_v1/report.json`](../../generated/blender/supply_cart_v1/report.json) - deterministic `cart_2w` geometry/material checks.

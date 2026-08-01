# Spring 1343 Reval merchant-cart art brief

**Task:** A-010 / R-7
**Historical anchor:** Spring 1343 Reval, Lower Town, harbour margin, wall yards, and Harju approaches
**Primary dossier:** [`history/dossiers/economy/merchant-cart-and-transport-1340s.md`](../../history/dossiers/economy/merchant-cart-and-transport-1340s.md) (R-068, status `solid`)
**Toll-gap dossier:** [`history/dossiers/economy/reval-cart-tolls-and-fuhr-rent-1340s.md`](../../history/dossiers/economy/reval-cart-tolls-and-fuhr-rent-1340s.md) (R-069, no attested 1340-1343 cart toll)
**Production contract:** [`docs/reports/merchant_cart_transport_contract.md`](merchant_cart_transport_contract.md) (P0-164)
**Evidence status:** The three PNGs in this brief are deterministic Blender visual studies for non-runtime art direction. They are not archaeological reconstructions, licensed source photographs, or runtime assets. Historical comparanda remain in `history/reference/` and are cited by plate ID below.

## 1. Brief ship decisions

Use the pack to author Spring-1343 supply traffic, not military transport or modern farm equipment. The default urban vehicle is a small two-wheel horse *Karren*. A four-wheel wagon is a larger, slower heavy-load exception at the harbour or wall-building margin. A hand barrow serves the forum throat and shop diele where a wheeled vehicle would be too large.

- **Draught:** horse for town supply and Harju carting. Do not use an ox team as the urban default.
- **Loads:** inbound grain sacks, beer barrels, salt kegs, iron-bar bundles, and charcoal sacks; outbound hemp/flax bales, hides, and empty barrels.
- **Season:** after St George's Night on 23 April, inland grain and charcoal carts stall. Harbour lighter-to-cart movement may continue under siege pressure.
- **Construction language:** weathered oak or ash frame, elm-like wheel stock, dark wrought iron straps and nails, wicker or lattice sides, linen and wood load props.
- **Metric hook:** author the cart class around the approximately 1.3 m wheel track. This applies the 1.26-1.40 m Tallinn rut find to the 1343 production composite; it is not a measured 1343 house-plot cart.
- **Toll gap:** do not add a gate toll booth, wheel tax, or pfennig-per-axle UI. R-069 leaves `cart_toll_pfennig` null. Cargo weighing, harbour dues, market-order fines, and curfew enforcement are separate systems and must not be represented as an attested cart tariff.

## 2. Vehicle class matrix

| `vehicle_class` | Art read | Wheels / draught | Default 1343 use | Confidence | Load direction |
|---|---|---|---|---|---|
| `cart_2w` | Small open-front *Karren* with lattice or wicker sides, hinged rear gate, two load props, and a single horse in shafts | 2 wheels; 1 horse, with a second only for steep work | **Default** on forum throats, lanes, Pikk/Lai deliveries, and ordinary harbour approaches | **plausible composite** [R-068 1-3, 7] | 2-4 grain sacks, 1-2 beer barrels, salt, iron, charcoal; hemp/flax and hides outbound |
| `wagon_4w` | Broad, longer freight wagon with four wheels, heavier platform, higher load capacity, and a slower turning footprint | 4 wheels; 2-4 horses | **Exception** for harbour margins, timber/stone work, and wall yards; never the default alley vehicle | **plausible composite** [R-068 2, 7] | Timber, stone blocks, or multiple cloth bales; bulk harbour transfer |
| `barrow` | Human hand or sack barrow: shallow board, two handles, modest sack/crate load, no vehicle draught | No draught animal; human porter | **Forum throat and shop diele** where a cart cannot turn or should not block the lane | **plausible composite** [R-068 vehicle table] | One sack, crate, chest, or short shop delivery |

The R-068 dossier also names `sledge` as a winter or mud-season class. It is intentionally outside this April cart plate pack: do not substitute runners for the late-April cobbled-street default.

## 3. Documentation-only plate pack

All three files are under `docs/reports/images/merchant_carts/`. They are production studies, not evidence plates and must not be copied into `assets/`, loaded by runtime scenes, or added to `assets/SOURCES.csv`.

| Plate | Class | Study read | Historical decision supported |
|---|---|---|---|
| [`reference_cart_2w.png`](images/merchant_carts/reference_cart_2w.png) | `cart_2w` | Open-front two-wheel horse cart, approximately 1.3 m track, lattice sides, hinged rear gate, sacks and barrel | Default urban Karren silhouette, single-horse shafts, modest spring load, weathered wood and dark iron |
| [`reference_wagon_4w.png`](images/merchant_carts/reference_wagon_4w.png) | `wagon_4w` | Wider four-wheel freight wagon with a heavy platform, bulk load, and two-horse study team | Harbour/wall-yard exception; broad turning footprint and bulk role rather than alley traffic |
| [`reference_barrow.png`](images/merchant_carts/reference_barrow.png) | `barrow` | Human hand barrow with handles, shallow board, two sacks, crate, and porter proxy | Forum/shop delivery scale; no horse, no axle, no cart queue footprint |

### Historical comparanda used by the studies

- `economy.merchant-cart-and-transport-1340s.01`: Mendel Hausbuch I 110r, 1494 Nuremberg, public domain. Later comparandum for the two-wheel carter and horse silhouette; not a direct 1343 Reval image.
- `economy.merchant-cart-and-transport-1340s.02`: Catalan Atlas, 1375 Majorca, public domain. Later comparandum for four-wheel caravan proportions and heavy-load spacing; not a direct Reval wagon record.
- `economy.merchant-cart-and-transport-1340s.03`: PAS FindID 232991, 1200-1400, CC BY-SA 4.0. Horse-shoe material reference; it does not establish a cart body.
- `economy.merchant-cart-and-transport-1340s.04`: AVE 2018:13 Fig. 6, linked-only Tallinn 15th-century landfill plan. Supports the 1.26-1.40 m rut spacing used as a restrained 1343 composite.
- `economy.merchant-cart-and-transport-1340s.05`: Tacuinum Sanitatis, 15th-century France, public-domain source row currently marked failed/link-only. It is a later lattice-side harvest-cart comparandum, not proof of a Reval 1343 form.

## 4. Shared art rules

### Silhouette and construction

1. Keep `cart_2w` visibly light, open, and manoeuvrable. The front remains open around the shafts; the rear gate is hinged and lower than a war-wagon breastwork.
2. Keep `wagon_4w` visibly wider and slower. Use a broad platform and four separate wheels, but avoid armoured sides, firing positions, towers, or a covered caravan body.
3. Keep `barrow` human-scale. It has handles and a shallow load board, not a horse shaft, axle train, or vehicle queue footprint.
4. Use six to twelve spoke wheels with dark iron rim strakes as a restrained composite. The 1.3 m track is a street-authoring metric, not permission to enlarge the body into a modern wagon.
5. Treat hoists, shafts, wheels, and rear gates as functional cues. Do not decorate them into civic emblems or late-medieval military hardware.

### Materials, wear, and values

- Frame: weathered grey-brown oak or ash with visible darker joints and repair variation.
- Side work: muted willow/wicker lattice; do not use bright new basket colour across every surface.
- Metal: dark wrought iron with restrained rust, not polished steel or painted modern hardware.
- Loads: undyed linen sacks, dark timber barrels, salt kegs, iron bars, charcoal sacks, hemp/flax bales, and bundled hides. Keep load variants removable for seasonal staging.
- Wear: mud at wheels and lower boards, hand-polished shaft grips, worn gate edges, and soot or charcoal dust only where the load warrants it.
- Value hierarchy: wheel and load edges must remain readable against cobble, mud, and harbour timber at gameplay distance; the studies are not a licence for glossy plastic or unlit black props.

## 5. Corridor and seasonal staging

| Corridor | Preferred class | Art note |
|---|---|---|
| Vanaturg east throat -> Raekoja plats | `cart_2w`, `barrow` | Pre-siege queue and barrel roll; barrows fill the human-scale gaps without twin-cart passing |
| Pikk / Lai frontage | `cart_2w`, `barrow` | Single-cart delivery fronts; back lanes under 3 m must not stage two carts passing |
| Harbour / Lootsi margin | `cart_2w`, optional `wagon_4w` | Barrel and timber bulk; four-wheeler reads as an exception tied to lightering or wall work |
| Viru Gate apron | `cart_2w` | Inbound Harju grain before 23 April; mark inland grain and charcoal traffic stallable afterwards |
| Wall-building yard | `wagon_4w` | Stone and timber bulk only; keep it out of ordinary Lower Town alley dressing |

Do not invent a toll booth at Viru, the Coastal Gate, or the harbour margin. A watch, weigh point, queue marker, or market-order interaction may exist when owned by its relevant system, but the cart art itself must not imply an attested wheel levy.

## 6. Rejection rules and anachronism lock

Reject any candidate or placement showing:

1. A Hussite **war-wagon** or missile-platform silhouette: breastworks, firing slots, armoured panels, towered sides, or a defensive ring.
2. **Ox** teams as the default urban draught. A horse is the required town-supply read.
3. **Victorian spring carts**, coach springs, leaf springs, pneumatic or **rubber tyres**, or modern metal-bodied farm carts.
4. Covered Conestoga or prairie-wagon bodies, painted municipal fleet livery, or a modern dung-cart identity. R-069 provides no attested 1343 municipal dung-cart roster.
5. `wagon_4w` staged as ordinary forum or alley traffic, especially on lanes below the 3 m passing constraint.
6. Gate toll booths, axle counters, pfennig-per-wheel labels, or UI that presents the R-069 gap as a settled tariff.
7. A barrow enlarged to cart scale, fitted with a horse shaft, or staged as a vehicle with an invented wheel track.

## 7. Non-runtime evidence boundary and handoff

The three PNGs are art-direction studies only. They remain in `docs/reports/images/merchant_carts/` and are deliberately absent from `assets/SOURCES.csv`. The historical source images remain under `history/reference/` according to the reference-plate manifest; generated studies are never historical evidence.

Downstream handoff:

- **A-004:** build or maintain the production `cart_2w` Karren mesh from this brief, keeping the two-wheel default and no war-wagon features.
- **P2-068:** author `wagon_4w`, `barrow`, load props, mesh-builder selection, and horse pairing without changing the class allowlist.
- **P2-069:** place classes on the named corridors, retain the 1.3 m rut tag and 2.5 m minimum cart path, and forbid twin-cart staging on narrow lanes.
- **P2-070 / P4-037:** wire seasonal traffic and carter systems; use `cart_toll_pfennig: null` unless new evidence closes R-069.
- **A-011:** review day/night gameplay-camera captures against the three studies, R-068 confidence labels, and the rejection list before visual sign-off.

## 8. Review checklist

- [x] At least one documentation-only plate exists for each closed class: `cart_2w`, `wagon_4w`, and `barrow`.
- [x] `cart_2w` is explicitly the default urban vehicle and shows a horse, open front, lattice/wicker sides, hinged rear gate, and approximately 1.3 m track.
- [x] `wagon_4w` is restricted to harbour/wall-yard heavy bulk and is not the alley default.
- [x] `barrow` is a human porter tool for forum/shop scale, not a horse vehicle.
- [x] R-068 confidence labels are preserved as **plausible composite** for all three production classes, with the rut find's attested/plausible-composite boundary retained.
- [x] Spring loads and the post-23-April inland stall are recorded.
- [x] R-069's missing wheel-tax/cart-toll evidence is recorded as a gap; no toll booth or axle fee is authorised.
- [x] War-wagon, ox-team default, Victorian spring cart, and rubber tyre anachronisms are explicitly rejected.
- [x] Synthetic PNG studies are kept outside runtime assets and provenance registration.

## Sources

1. [`merchant-cart-and-transport-1340s.md`](../../history/dossiers/economy/merchant-cart-and-transport-1340s.md), especially ship decisions 1-8, vehicle typology, corridor table, and reference plates `.01`-.`.05`.
2. [`reval-cart-tolls-and-fuhr-rent-1340s.md`](../../history/dossiers/economy/reval-cart-tolls-and-fuhr-rent-1340s.md), especially the explicit 1340-1343 wheel-tax/Fuhr-rent gap and no-toll-booth production hooks.
3. [`merchant_cart_transport_contract.md`](merchant_cart_transport_contract.md), closed class allowlist, metric constants, corridor allowlist, seasonal load bands, and rejection rules.
4. [`history/reference/plates.csv`](../../history/reference/plates.csv), rows for `economy.merchant-cart-and-transport-1340s.01`-.`.05`, including rights and fetch/link status.
5. [`history/reference/README.md`](../../history/reference/README.md), evidence-versus-asset boundary and license handling.

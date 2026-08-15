---
domain: topography
slug: karja-gate-leaf-state-1343
status: partial
consumers: [map, art, dev, quest]
related:
  - ./walls-gates-towers.md
  - ./lower-town-street-plan.md
  - ../../../docs/HISTORICAL_AUDIT.md
updated: 2026-08-15
---

# Karja Gate leaf state and material (Spring 1343)

## Brief for Dev

- `gate_presence_1343`: **plausible composite** - an early-14th-century wall/gate reconstruction at the Karja/Cattle Gate is compatible with the available synthesis, but the exact 1343 superstructure is not established [2][3].
- `gate_leaf_state_1343`: **null / unknown**. No accessible source inspected this tick establishes an open or closed leaf, a passage-only opening, or a normal operating state for Spring 1343 [1][2].
- `leaf_material_1343`: **null / unknown**. No accessible source inspected this tick identifies an iron, timber, or other material for a 1343 Karja Gate leaf [1][2].
- Keep the two fields independent. Do not infer metal from the runtime `door_material: metal` value or from `GateDoor0`; those are implementation contracts, not historical evidence [4].
- If the current Dev contract needs a visible leaf, label it as a reversible non-canon implementation choice and preserve both historical fields as unknown until the AVE article or an archive-supplied equivalent is inspected.

## Findings

### 1. Gate presence is not leaf-state evidence

The existing fortification synthesis treats Karja/Cattle Gate as an early-14th-century wall/gate reconstruction that is plausible for the 1343 map, while explicitly keeping the exact 1343 superstructure and watermill state uncertain [2][3]. This supports a gate anchor for map authoring, not a claim about whether a leaf was open or closed at a particular spring moment. **plausible composite** [2][3]

The same synthesis separates later written attestations from the campaign date: the name *Kariestrate* is first recorded in 1365, and later barbican forms are excluded from Spring 1343 [2][3]. A dated name or later defensive addition cannot supply a 1343 door-state or leaf-material verdict. **attested for the later record; not evidence for the 1343 leaf** [2][3]

### 2. `gate_leaf_state_1343`

**Verdict: `null` / unknown.** The registered archaeological source is Nurk et al., AVE 2010, “Observations about the early history of the suburb in front of the Karja Gate in Tallinn.” The repository has no matching local PDF, and the official PDF request timed out after 20 seconds without response headers or a file signature on 2026-08-15 00:05 UTC [1]. The existing project synthesis cites the article for an early-14th-century wall/gate reconstruction but does not expose a leaf-state observation [2]. This is an access boundary, not an archaeological or manuscript no-hit. **unknown** [1][2]

The available general wall chronology establishes that medieval Tallinn gates and passages belong to a changing fortification programme, with Spring 1343 completion itself uncertain; it does not establish whether Karja's passage was open, closed, or fitted with a particular closure at the moment represented [3][5]. **attested chronology; leaf state unknown** [3][5]

### 3. `leaf_material_1343`

**Verdict: `null` / unknown.** Neither the accessible project synthesis nor the inaccessible AVE article can be used in this tick to identify a 1343 leaf as iron/metal, timber, or another material [1][2]. The runtime map's `door_material: metal` and the expected `Landmark_karja_gate_arch/GateDoor0` node are downstream implementation context supplied by the task, not a period source [4]. **unknown** [1][2][4]

Do not use a generic medieval gate reconstruction, a later barbican, or the existence of ironwork elsewhere in Reval to upgrade this field. Such a transfer would be a **plausible composite** at best, not direct Karja evidence, and is not authorised by this dossier [2][3].

## Access and evidence boundary

- **Registered source:** Nurk et al., AVE 2010, “Observations about the early history of the suburb in front of the Karja Gate in Tallinn,” official URL: <https://arheoloogia.ee/ave2010/AVE2010_07_Nurkjt_Karja-Gate.pdf> [1].
- **Local check:** `history/AVE2010_07_Nurkjt_Karja-Gate.pdf` is absent from this checkout.
- **Direct fetch check:** `curl -L --max-time 20` on 2026-08-15 00:05 UTC timed out after 20 seconds; no response headers, PDF MIME type, or `%PDF` signature was obtained.
- The official AVE 2010 catalogue/index was surfaced by search, but the article body was not inspected; catalogue discovery does not replace the source [1].
- No claim is made that the article contains no leaf, door, hinge, or material evidence. The relevant fields remain `null` until a provenance-preserving copy, authenticated archive access, or an accessible official transcription is available.

## Production hooks

- **Map:** Retain the stable `karja_gate_arch` anchor and the early-14th-century simple gate/wall mass only as a **plausible composite**. Do not add a 1343 barbican, later watermill composition, or a supposedly attested leaf state [2][3].
- **Art:** A visible gate leaf may be authored for readability, but mark the choice as non-canon and avoid presenting iron/metal as historically verified. Keep the silhouette simple and reversible pending source access [1][2].
- **Quest / Narrative:** A gate checkpoint, patrol gap, or passage choice can use open/closed state as gameplay state, but the dialogue or quest text must not say that 1343 Karja evidence proves an iron gate or a normally closed passage [2][4].
- **Dev / systems:** For downstream `R-507`, consume `gate_leaf_state_1343: null` and `leaf_material_1343: null`. The `GateDoor0` and metal-door contract may remain an explicit implementation choice for the acceptance test, not a canon assertion. Do not weaken or rewrite that test from this research task [4].

## Reference plates

No licensed visual evidence specifically showing a Spring-1343 Karja Gate leaf, hinge, or leaf material was found in the accessible source set this tick. The AVE 2010 article is an access-bound source, so no image was downloaded or registered as a plate. Generated images are not evidence.

## Cross-references

- [`walls-gates-towers.md`](./walls-gates-towers.md) - supplies the existing eight-gate chronology, Karja presence boundary, and exclusions for later barbicans and superstructure.
- [`lower-town-street-plan.md`](./lower-town-street-plan.md) - places the Karja approach in the southern route network while keeping the 1365 name later than the campaign date.
- [`../../../docs/HISTORICAL_AUDIT.md`](../../../docs/HISTORICAL_AUDIT.md) - H10 records the AVE Karja source and the unresolved 1343 superstructure boundary.

## Open questions

- Can an authenticated or archive-supplied copy of AVE 2010, pp. 105-110 or its Karja Gate figures, identify a closure, hinge, threshold, or leaf material with a dated context?
- Does the AVE article distinguish the early-14th-century wall/gate reconstruction from later watermill or barbican phases at the exact Karja passage?
- If direct archaeology remains silent, is there a dated Reval, Danish Estonia, or Hanseatic comparator close enough in date and gate type to support a clearly labelled **plausible composite** visual choice without changing the two null fields?

## Sources

1. Nurk, J. et al., “Observations about the early history of the suburb in front of the Karja Gate in Tallinn,” *Archaeological Fieldwork in Estonia 2010*, official PDF: <https://arheoloogia.ee/ave2010/AVE2010_07_Nurkjt_Karja-Gate.pdf> (Estonian/English publication record; article body inaccessible in this tick).
2. [`../../../docs/HISTORICAL_AUDIT.md`](../../../docs/HISTORICAL_AUDIT.md), H10, “Nurk et al., Karja Gate archaeology” - early rubble/pebble road, coastal-lowland relief, road-aligned suburb, early-14th-century wall/gate reconstruction; exact 1343 superstructure and watermill state uncertain (project synthesis, English).
3. [`./walls-gates-towers.md`](./walls-gates-towers.md), Findings and Sources [1], [7], [8] - eight-gate mid-14th-century scheme, Karja presence as plausible composite, 1365 name, and later-barbican exclusions (project dossier, English).
4. Task handoff for `R-507`, including `content/maps/south_quarter.rrmap` (`karja_gate_arch`, `door_material: metal`) and `Landmark_karja_gate_arch/GateDoor0` - implementation context only, not historical evidence.
5. Medieval Heritage, “Tallinn city defensive walls,” <https://medievalheritage.eu/en/main-page/heritage/estonia/tallinn-city-defensive-walls/> - general synthesis of Tallinn fortification phases and later wall growth; does not identify a Karja 1343 leaf or material (English).
